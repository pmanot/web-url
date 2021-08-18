// Copyright The swift-url Contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// A description of a file path's structure.
///
public struct FilePathFormat: Equatable, Hashable, CustomStringConvertible {

  @usableFromInline
  internal enum _Format {
    case posix
    case windows
  }

  @usableFromInline
  internal var _fmt: _Format

  @inlinable
  internal init(_ _fmt: _Format) {
    self._fmt = _fmt
  }

  /// A path which is compatible with the POSIX standard.
  ///
  /// ## Format
  ///
  /// The format and interpretation of POSIX-style paths is documented by [IEEE Std 1003.1][POSIX-4-13].
  ///
  /// ## Code Units
  ///
  /// The path separator is `/` (code-unit value `0x2F`),
  /// and the current/parent directory is represented by `.`/`..` respectively (where `.` is the code-unit with value `0x2E`).
  /// All other code-units are not defined and must be preserved exactly.
  ///
  /// ## Normalization
  ///
  /// Consecutive separators have the same meaning as a single separator, except if the path starts with exactly 2 separators.
  ///
  /// [POSIX-4-13]: https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap04.html#tag_04_13
  ///
  @inlinable
  public static var posix: FilePathFormat {
    FilePathFormat(.posix)
  }

  /// A path which is compatible with those used by Microsoft Windows.
  ///
  /// ## Format
  ///
  /// There are many, many Windows path formats. This object represents the most common ones:
  ///
  /// - DOS paths: `C:\Users\Alice\Desktop\family.jpg`
  /// - UNC paths: `\\us-west.example.com\files\meeting-notes-june.docx`
  /// - DOS long paths: `\\?\C:\Users\Bob\Documents\...`
  /// - UNC long paths: `\\?\UNC\europe.example.com\jim\...`
  ///
  /// The precise format and interpretation of these paths is documented by Microsoft:
  /// - [File path formats on Windows systems][MS-PathFormat]
  /// - [Naming Files, Paths, and Namespaces][MS-FileNaming]
  /// - [UNC Path specification][MS-UNCSPEC]
  ///
  /// ## Code Units
  ///
  /// The code-units of Windows file paths natively represent Unicode code-points. Windows provides APIs which encode these paths using
  /// either UTF-16 code-units, or ANSI code-units in the system's active code-page (a form of extended ASCII). In either case, the numeric
  /// values of code-units in the ASCII range may be interpreted as ASCII characters.
  /// File and directory names are not normalized, so the sequence of Unicode code-points must be preserved exactly.
  ///
  /// The preferred path separator is `\` (code-unit value `0x5C`), although some formats also accept `/` (`0x2F`).
  /// The current/parent directory is represented by `.`/`..` respectively (where `.` is the code-unit with value `0x2E`).
  ///
  /// Non-ASCII code-units in path components are treated as opaque. An exception is UNC paths, where the hostname component must be UTF-8.
  ///
  /// ## Normalization
  ///
  /// Consecutive separators have the same meaning as a single separator, except if the path starts with exactly 2 separators.
  /// Trailing ASCII periods and spaces may be trimmed from path components - a file named `foo.` cannot be expressed using regular DOS paths.
  /// Long paths are not normalized, so they can express the file name `foo.`. However, many Windows APIs will normalize them regardless.
  ///
  /// See [File path formats on Windows systems][MS-PathFormat] for a description of Windows' path normalization procedure.
  ///
  /// [MS-PathFormat]: https://web.archive.org/web/20210714174116/https://docs.microsoft.com/en-us/dotnet/standard/io/file-path-formats
  /// [MS-FileNaming]: https://web.archive.org/web/20210716121600/https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
  /// [MS-UNCSPEC]: https://web.archive.org/web/20210708165404/https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/62e862f4-2a51-452e-8eeb-dc4ff5ee33cc
  ///
  @inlinable
  public static var windows: FilePathFormat {
    FilePathFormat(.windows)
  }

  /// The native path style used by the current operating system.
  ///
  @inlinable
  public static var native: FilePathFormat {
    #if os(Windows)
      return .windows
    #else
      return .posix
    #endif
  }

  public var description: String {
    switch _fmt {
    case .posix: return "posix"
    case .windows: return "windows"
    }
  }
}


// --------------------------------------------
// MARK: - File path to URL
// --------------------------------------------


extension WebURL {

  /// Creates a `file:` URL representation of the given file path.
  ///
  /// This is a low-level API, which accepts a file path as a `Collection` of 8-bit code-units. Correct usage requires detailed knowledge
  /// of character sets and text encodings, and how various operating systems and filesystems consider file paths internally.
  /// It is useful for niche cases requiring specific control over the file path's representation (such as if you are on Windows and require a URL
  /// containing percent-encoded Latin-1 code-units for compatibility with a legacy application), but users should generally prefer
  /// `WebURL.init(filePath: FilePath/String)`.
  ///
  /// ## Supported paths
  ///
  /// This function only supports non-relative paths (i.e. absolute POSIX paths, fully-qualified Windows paths), which do not contain any `..` components
  /// or ASCII `NULL` bytes. The terminator of a null-terminated string should not be included in the given collection of octets.
  ///
  /// These restrictions are considered a feature. URLs have no way of expressing relative paths, so such paths would first have to be resolved against
  /// a base path or working directory. Components which traverse upwards in the filesystem and unexpected NULL bytes are common sources of
  /// [security vulnerabilities][OWASP-PathTraversal]. Best practice is to first resolve and normalize such paths before turning them in to URLs,
  /// so you have an opportunity to check where the path actually points to.
  ///
  /// ## Special Windows paths
  ///
  /// This function supports Win32 file namespace paths (a.k.a. "namespaced" or "long" paths) only if they contain a drive letter or point to a UNC location.
  /// These paths are identified by the prefix `\\?\`.
  ///
  /// In a deliberate departure from Microsoft's documentation, empty and `.` components will be resolved in these paths.
  /// Other path components will not be trimmed or otherwise altered. This library considers this minimal structural normalization to be safe,
  /// as empty components have no meaning on any filesystem, and all commonly-used filesystems on Windows (including FAT, exFAT, NTFS, and ReFS)
  /// forbid files and directories named `.`. SMB/CIFS and NFS (the most common protocols used with UNC) likewise define that `.` components
  /// refer to the current directory.
  ///
  /// Additionally, `..` components and forward slashes are forbidden, as they represent components literally named `..` or with forward slashes in
  /// their name. However, Windows APIs are not consistent, and will sometimes interpret these as traversal instructions or path separators regardless.
  /// This ambiguity means that accepting such components could lead to hidden directory traversal and other security vulnerabilities.
  /// Again, no commonly-used filesystem on Windows supports these file or directory names anyway, and the network protocols listed above also forbid them.
  ///
  /// ## Encodings
  ///
  /// While we may usually think of file and directory names strings of text, some operating systems do not treat them that way.
  /// Behaviours vary greatly between operating systems, from fully-defined code-units which are normalized by the system (Apple OSes),
  /// to fully-defined code-units which are not normalized (Windows), to opaque, numeric code-units with no defined interpretation (Linux, general POSIX).
  ///
  /// In order to process a path, we need to at least understand its structure. This is determined by the provided `FilePathFormat`,
  /// and informs the function how the given code-units should be interpreted - e.g. which values are reserved as path separators, which normalization rules apply,
  /// and whether or not the code-units can be interpreted as textual code-points.
  ///
  /// POSIX paths generally cannot be transcoded and should be provided to the function in their native 8-bit encoding.
  /// Windows paths should be transcoded from their native UTF-16 to UTF-8.
  /// Windows paths may also be provided in their per-system ANSI encoding, but this is discouraged and should only be used
  /// when specific legacy considerations demand it.
  ///
  /// ## Normalization
  ///
  /// Some basic lexical normalization is applied to the path, according to the given `FilePathFormat`.
  ///
  /// For example, empty path components may be collapsed and some file or directory names trimmed.
  /// Refer to the documentation for `FilePathFormat` for information about the kinds of normalization which each format defines.
  ///
  /// [OWASP-PathTraversal]: https://owasp.org/www-community/attacks/Path_Traversal
  ///
  /// - parameters:
  ///   - path:   The file path, as a `Collection` of 8-bit code-units.
  ///   - format: The way in which `path` should be interpreted; either `.posix`, `.windows`, or `.native`.
  ///
  /// - returns: A URL with the `file` scheme which can be used to reconstruct the given path.
  /// - throws: `FilePathToURLError`
  ///
  @inlinable
  public static func fromFilePathBytes<Bytes>(
    _ path: Bytes, format: FilePathFormat = .native
  ) throws -> WebURL where Bytes: BidirectionalCollection, Bytes.Element == UInt8 {
    switch format._fmt {
    case .posix: return try _filePathToURL_posix(path).get()
    case .windows: return try _filePathToURL_windows(path).get()
    }
  }
}

/// The reason why a file URL could not be created from a given file path.
///
public struct FilePathToURLError: Error, Equatable, Hashable, CustomStringConvertible {

  @usableFromInline
  internal enum _Err {
    case emptyInput
    case nullBytes
    case relativePath
    case upwardsTraversal
    case invalidHostname
    case invalidWin32NamespacedPath
    case unsupportedWin32NamespacedPath
    case transcodingFailure
  }

  @usableFromInline
  internal var _err: _Err

  @inlinable init(_ _err: _Err) {
    self._err = _err
  }

  /// The given path is empty.
  ///
  @inlinable
  public static var emptyInput: FilePathToURLError {
    FilePathToURLError(.emptyInput)
  }

  /// The given path contains ASCII `NULL` bytes.
  ///
  /// `NULL` bytes are forbidden, to protect against injected truncation.
  ///
  @inlinable
  public static var nullBytes: FilePathToURLError {
    FilePathToURLError(.nullBytes)
  }

  /// The given path is not absolute/fully-qualified.
  ///
  /// Each path style has different kinds of relative paths. Use APIs provided by the platform, or the `swift-system` library, to resolve the input
  /// as an absolute path. Be advised that some kinds of relative path resolution may not be thread-safe; consult your chosen path API for details.
  ///
  @inlinable
  public static var relativePath: FilePathToURLError {
    FilePathToURLError(.relativePath)
  }

  /// The given path contains one or more `..` components.
  ///
  /// These components are forbidden, to protect against directory traversal attacks. Use APIs provided by the platform, or the `swift-system` library,
  /// to resolve the path. Users are advised to check that the path has not escaped the expected area of the filesystem after it has been resolved.
  ///
  @inlinable
  public static var upwardsTraversal: FilePathToURLError {
    FilePathToURLError(.upwardsTraversal)
  }

  /// The given path is a Windows UNC path, but the hostname is not valid or cannot be represented in a URL.
  ///
  /// Note that currently, only ASCII domains, IPv4, and IPv6 addresses are supported. Domains may not include [forbidden host code-points][URL-FHCP].
  ///
  /// [URL-FHCP]: https://url.spec.whatwg.org/#forbidden-host-code-point
  ///
  @inlinable
  public static var invalidHostname: FilePathToURLError {
    FilePathToURLError(.invalidHostname)
  }

  /// The given path has a Win32 file namespace path (a.k.a. "long" path) prefix, but contains invalid syntax which prohibits a URL representation
  /// from being formed.
  ///
  /// Examples of invalid syntax:
  /// - `\\?\` (no path following prefix)
  /// - `\\?\\` (device name is empty)
  /// - `\\?\C:` (no trailing slash after device name)
  /// - `\\?\UNC` (no trailing slash after device name)
  ///
  @inlinable
  public static var invalidWin32NamespacedPath: FilePathToURLError {
    FilePathToURLError(.invalidWin32NamespacedPath)
  }

  /// The given path is a Win32 file namespace path (a.k.a. "long" path), but references an object for which a URL representation cannot be formed.
  ///
  /// Win32 file namespace paths have a variety of ways to reference files - for instance, both `\\?\BootPartition\Users\`
  /// and `\\?\HarddiskVolume2\Users\` might resolve to `\\?\C:\Users\`. These more exotic paths are currently not supported.
  ///
  /// Win32 file namespace paths are documented as opting-out from typical path normalization, meaning that characters such as forward slashes
  /// represent literal slashes in a file or directory name. Some Windows APIs respect this, while others do not, meaning that these characters are ambiguous
  /// and can potentially lead to security vulnerabilities via smuggled path components. For this reason, they are not supported.
  ///
  @inlinable
  public static var unsupportedWin32NamespacedPath: FilePathToURLError {
    FilePathToURLError(.unsupportedWin32NamespacedPath)
  }

  // '.transcodingFailure' is thrown by higher-level functions (e.g. System.FilePath -> WebURL),
  // but defined as part of FilePathToURLError.

  /// Transcoding the given path for inclusion in a URL failed.
  ///
  /// File URLs can preserve the precise bytes of their path components by means of percent-encoding.
  /// However, when the platform's native path representation uses non-8-bit code-units, those elements must be transcoded
  /// to an 8-bit encoding suitable for percent-encoding.
  ///
  @inlinable
  public static var transcodingFailure: FilePathToURLError {
    FilePathToURLError(.transcodingFailure)
  }

  public var description: String {
    switch _err {
    case .emptyInput: return "Path is empty"
    case .nullBytes: return "Path contains NULL bytes"
    case .relativePath: return "Path is relative"
    case .upwardsTraversal: return "Path contains upwards traversal"
    case .invalidHostname: return "Path references an invalid hostname"
    case .invalidWin32NamespacedPath: return "Invalid Win32 namespaced path"
    case .unsupportedWin32NamespacedPath: return "Unsupported Win32 namespaced path"
    case .transcodingFailure: return "Transcoding failure"
    }
  }
}

/// Creates a `file:` URL from a POSIX-style path.
///
/// The bytes must be in a 'filesystem-safe' encoding, but are otherwise just opaque bytes.
///
@inlinable @inline(never)
internal func _filePathToURL_posix<Bytes>(
  _ path: Bytes
) -> Result<WebURL, FilePathToURLError> where Bytes: BidirectionalCollection, Bytes.Element == UInt8 {

  guard !path.isEmpty else {
    return .failure(.emptyInput)
  }
  guard !path.contains(ASCII.null.codePoint) else {
    return .failure(.nullBytes)
  }
  guard !path.containsLiteralDotDotComponent(isSeparator: { $0 == ASCII.forwardSlash.codePoint }) else {
    return .failure(.upwardsTraversal)
  }
  guard path.first == ASCII.forwardSlash.codePoint else {
    return .failure(.relativePath)
  }

  var escapedPath = ContiguousArray(path.lazy.percentEncoded(as: \.posixPath))

  // Collapse multiple path slashes into a single slash, except if a leading double slash ("//usr/bin").
  // POSIX says that leading double slashes are implementation-defined.

  precondition(escapedPath[0] == ASCII.forwardSlash.codePoint)

  if escapedPath.count > 2 {
    if escapedPath[1] == ASCII.forwardSlash.codePoint, escapedPath[2] != ASCII.forwardSlash.codePoint {
      escapedPath.collapseForwardSlashes(from: 2)
    } else {
      escapedPath.collapseForwardSlashes(from: 0)
    }
  }

  // We've already encoded or rejected most things the URL path parser will interpret
  // (backslashes, Windows drive delimiters, etc), with the notable exception of single-dot components.
  // The path setter will encode anything else that URL semantics would interpret.

  var fileURL = _emptyFileURL
  try! fileURL.utf8.setPath(escapedPath)
  return .success(fileURL)
}

/// Creates a `file:` URL from a Windows-style path.
///
/// The bytes must be some kind of extended ASCII (either UTF-8 or any ANSI codepage). If a UNC server name is included, it must be UTF-8.
///
@inlinable @inline(never)
internal func _filePathToURL_windows<Bytes>(
  _ path: Bytes
) -> Result<WebURL, FilePathToURLError> where Bytes: BidirectionalCollection, Bytes.Element == UInt8 {

  guard !path.isEmpty else {
    return .failure(.emptyInput)
  }
  guard !path.contains(ASCII.null.codePoint) else {
    return .failure(.nullBytes)
  }

  if !isWindowsFilePathSeparator(path.first!) {
    // No prefix; parse as a regular DOS path.
    return _filePathToURL_windows_DOS(path, trimComponents: true)
  }

  if path.starts(with: #"\\?\"#.utf8) {
    // Win32 file namespace path.
    let pathWithoutPrefix = path.dropFirst(4)
    guard !pathWithoutPrefix.isEmpty else {
      return .failure(.invalidWin32NamespacedPath)
    }
    guard !pathWithoutPrefix.contains(ASCII.forwardSlash.codePoint) else {
      return .failure(.unsupportedWin32NamespacedPath)
    }
    let device = pathWithoutPrefix.prefix(while: { $0 != ASCII.backslash.codePoint })
    guard !device.isEmpty, device.endIndex < pathWithoutPrefix.endIndex else {
      return .failure(.invalidWin32NamespacedPath)
    }
    // Determine the kind of path from the device.
    if ASCII.Lowercased(device).elementsEqual("unc".utf8) {
      let uncPathContents = pathWithoutPrefix[pathWithoutPrefix.index(after: device.endIndex)...]
      guard !uncPathContents.isEmpty else {
        return .failure(.invalidWin32NamespacedPath)
      }
      return _filePathToURL_windows_UNC(uncPathContents, trimComponents: false)
    }
    if PathComponentParser.isNormalizedWindowsDriveLetter(device) {
      return _filePathToURL_windows_DOS(pathWithoutPrefix, trimComponents: false)
    }
    return .failure(.unsupportedWin32NamespacedPath)
  }

  let pathWithoutLeadingSeparators = path.drop(while: isWindowsFilePathSeparator)
  guard path.distance(from: path.startIndex, to: pathWithoutLeadingSeparators.startIndex) > 1 else {
    // 1 leading separator: drive-relative path.
    return .failure(.relativePath)
  }
  // 2+ leading separators: UNC.
  return _filePathToURL_windows_UNC(pathWithoutLeadingSeparators, trimComponents: true)
}

@inlinable @inline(never)
internal func _filePathToURL_windows_DOS<Bytes>(
  _ path: Bytes, trimComponents: Bool
) -> Result<WebURL, FilePathToURLError> where Bytes: BidirectionalCollection, Bytes.Element == UInt8 {

  // DOS-path = <alpha><":"><separator><...> ; e.g. "C:\Windows\", "D:/foo".

  guard !path.containsLiteralDotDotComponent(isSeparator: isWindowsFilePathSeparator) else {
    return .failure(.upwardsTraversal)
  }
  let driveLetter = path.prefix(2)
  guard PathComponentParser.isNormalizedWindowsDriveLetter(driveLetter) else {
    return .failure(.relativePath)
  }
  guard driveLetter.endIndex < path.endIndex else {
    return .failure(.relativePath)
  }
  guard isWindowsFilePathSeparator(path[driveLetter.endIndex]) else {
    return .failure(.relativePath)
  }

  var escapedPath = ContiguousArray(driveLetter)
  escapedPath.append(contentsOf: path[driveLetter.endIndex...].lazy.percentEncoded(as: \.windowsPath))

  escapedPath.collapseWindowsPathSeparators(from: 2)
  if trimComponents {
    escapedPath.trimPathSegmentsForWindows(from: 2, isUNC: false)
  }

  var fileURL = _emptyFileURL
  try! fileURL.utf8.setPath(escapedPath)
  return .success(fileURL)
}

@inlinable @inline(never)
internal func _filePathToURL_windows_UNC<Bytes>(
  _ path: Bytes, trimComponents: Bool
) -> Result<WebURL, FilePathToURLError> where Bytes: BidirectionalCollection, Bytes.Element == UInt8 {

  // UNC-postprefix = <hostname><separator share>?<separator path>?

  var fileURL = _emptyFileURL

  // UNC hostname.
  // This part must be valid UTF-8.

  let rawHost = path.prefix { !isWindowsFilePathSeparator($0) }
  do {
    // UNC paths must have a hostname.
    guard !rawHost.isEmpty else {
      return .failure(.invalidHostname)
    }
    // For now, since we don't support unicode domains (due to IDNA),
    // check that the hostname is ASCII and doesn't include percent-encoding.
    guard rawHost.allSatisfy({ ASCII($0) != nil }), !rawHost.contains(ASCII.percentSign.codePoint) else {
      return .failure(.invalidHostname)
    }
    // Reject "?" and "." as UNC hostnames.
    // Otherwise we might create something which looks like a Win32 file namespace/local device path.
    guard !rawHost.elementsEqual(CollectionOfOne(ASCII.questionMark.codePoint)) else {
      return .failure(.invalidHostname)
    }
    guard !rawHost.elementsEqual(CollectionOfOne(ASCII.period.codePoint)) else {
      return .failure(.invalidHostname)
    }
    // The URL standard does not preserve "localhost" as a hostname in file URLs,
    // but removing it would turn a UNC path in to a local path.
    // As a workaround, replace it with "127.0.0.1". https://github.com/whatwg/url/issues/618
    if ASCII.Lowercased(rawHost).elementsEqual("localhost".utf8) {
      var ipv4String = IPv4Address(octets: (127, 0, 0, 1)).serializedDirect
      withUnsafeBytes(of: &ipv4String.buffer) { try! fileURL.utf8.setHostname($0.prefix(Int(ipv4String.count))) }
    } else {
      guard let _ = try? fileURL.utf8.setHostname(rawHost) else {
        return .failure(.invalidHostname)
      }
    }
  }

  // UNC share & path.

  let rawShareAndPath = path.suffix(from: rawHost.endIndex)
  guard !rawShareAndPath.containsLiteralDotDotComponent(isSeparator: isWindowsFilePathSeparator) else {
    return .failure(.upwardsTraversal)
  }

  var escapedShareAndPath = ContiguousArray(rawShareAndPath.lazy.percentEncoded(as: \.windowsPath))

  escapedShareAndPath.collapseWindowsPathSeparators(from: escapedShareAndPath.startIndex)
  if trimComponents {
    escapedShareAndPath.trimPathSegmentsForWindows(from: escapedShareAndPath.startIndex, isUNC: true)
  }

  try! fileURL.utf8.setPath(escapedShareAndPath)
  return .success(fileURL)
}


// --------------------------------------------
// MARK: - File URL to path
// --------------------------------------------


extension WebURL {

  /// Reconstructs a file path from a `file:` URL.
  ///
  /// This is a low-level function, which returns a file path as a `Collection` of 8-bit code-units. Correct usage requires detailed knowledge
  /// of character sets and text encodings, and how various operating systems and file systems actually handle file paths internally.
  /// Most users should prefer higher-level APIs, which return a file path as a `String` or `FilePath`, as many of these details will be
  /// handled for you.
  ///
  /// ## Accepted URLs
  ///
  /// This function only accepts URLs with a `file` scheme, whose paths do not contain percent-encoded path separators or `NULL` bytes.
  /// Additionally, as there is no obvious interpretation of a POSIX path to a remote host, POSIX paths may only be constructed from URLs with empty hostnames.
  /// Windows paths must be fully-qualified: either they have a hostname and are UNC paths, or they have an empty hostname and begin with a drive letter
  /// component.
  ///
  /// Attempting to create a file path from an unsupported URL will throw a `URLToFilePathError`.
  ///
  /// ## Encoding
  ///
  /// This function returns an array of 8-bit code-units, formed by percent-decoding the URL's contents and applying format-specific path normalization.
  /// Note that the encoding of these code-units is, in general, not known.
  ///
  /// - To use the returned path on a POSIX system, request a null-terminated file path, and map/reinterpret the array's contents as the platform's `CChar` type.
  ///   POSIX requires that the C `char` type be 8 bits, so this is always safe. As POSIX systems generally do not assume any particular encoding for
  ///   file or directory names, it is reasonable to use the path as-is.
  ///
  /// - To use the returned path on a Windows system, some transcoding may be necessary as the system natively uses 16-bit code-units.
  ///   It is generally a good idea to assume that the path decoded from the URL is UTF-8, transcode it to UTF-16, add a null-terminator, and use it
  ///   with the `-W` family of APIs. The exception is when you happen to know that the 8-bit code-units used to create the URL were not UTF-8.
  ///
  /// ## Normalization
  ///
  /// Some basic normalization is applied to the path, according to the specific rules which govern how each path style is interpreted.
  ///
  /// For example, both POSIX- and Windows-style paths define that certain sequences of repeat path separators can be collapsed to a single separator
  /// (e.g. `/usr//bin/swift` is the same as `/usr/bin/swift`), but there are also other kinds of normalization which are specific to Windows paths.
  ///
  /// - parameters:
  ///   - url:    The file URL.
  ///   - format: The path format which should be constructed; either `.posix`, `.windows`, or `.native`.
  ///   - nullTerminated: Whether the returned file path should include a null-terminator. The default is `false`.
  ///
  /// - returns: A reconstruction of the file path encoded in the given URL, as an array of bytes.
  /// - throws: `URLToFilePathError`
  ///
  @inlinable
  public static func filePathBytes(
    from url: WebURL, format: FilePathFormat = .native, nullTerminated: Bool = false
  ) throws -> ContiguousArray<UInt8> {
    switch format._fmt {
    case .posix: return try _urlToFilePath_posix(url, nullTerminated: nullTerminated).get()
    case .windows: return try _urlToFilePath_windows(url, nullTerminated: nullTerminated).get()
    }
  }
}

/// The reason why a file path could not be created from a given URL.
///
public struct URLToFilePathError: Error, Equatable, Hashable, CustomStringConvertible {

  @usableFromInline
  internal enum _Err {
    case notAFileURL
    case encodedPathSeparator
    case encodedNullBytes
    case posixPathsCannotContainHosts
    case windowsPathIsNotFullyQualified
    case transcodingFailure
  }

  @usableFromInline
  internal var _err: _Err

  @inlinable
  internal init(_ _err: _Err) {
    self._err = _err
  }

  /// The given URL is not a `file:` URL.
  ///
  @inlinable
  public static var notAFileURL: URLToFilePathError {
    URLToFilePathError(.notAFileURL)
  }

  /// The given URL contains a percent-encoded path separator.
  ///
  /// Typically, percent-encoded bytes in a URL are decoded when generating a file path, as percent-encoding is a URL feature that has no meaning to
  /// a filesystem. However, if the decoded byte would be interpreted by the system as a path separator, decoding it would pose a security risk as it could
  /// be used by an attacker to smuggle extra path components, including ".." components.
  ///
  @inlinable
  public static var encodedPathSeparator: URLToFilePathError {
    URLToFilePathError(.encodedPathSeparator)
  }

  /// The given URL contains a percent-encoded `NULL` byte.
  ///
  /// Typically, percent-encoded bytes in a URL are decoded when generating a file path, as percent-encoding is a URL feature that has no meaning to
  /// a filesystem. However, if the decoded byte is a `NULL` byte, many systems would interpret that as the end of the path, which poses a security risk
  /// as an attacker could unexpectedly discard parts of the path.
  ///
  @inlinable
  public static var encodedNullBytes: URLToFilePathError {
    URLToFilePathError(.encodedNullBytes)
  }

  /// The given URL refers to a file on a remote host, which cannot be represented by a POSIX path.
  ///
  /// On POSIX systems, remote filesystems tend to be mounted at locations in the local filesystem.
  /// There is no obvious interpretation of a URL with a remote host on a POSIX system.
  ///
  @inlinable
  public static var posixPathsCannotContainHosts: URLToFilePathError {
    URLToFilePathError(.posixPathsCannotContainHosts)
  }

  /// The given URL does not resolve to a fully-qualified Windows path.
  ///
  /// file URLs cannot contain relative paths; they always represent absolute locations on the filesystem.
  /// For Windows platforms, this means it would be incorrect for a file URL to result in anything other than a fully-qualified path.
  /// Windows paths are fully-qualified if they are UNC paths (i.e. have hostnames), or if their first component is a drive letter with a trailing separator.
  ///
  @inlinable
  public static var windowsPathIsNotFullyQualified: URLToFilePathError {
    URLToFilePathError(.windowsPathIsNotFullyQualified)
  }

  // '.transcodingFailure' is thrown by higher-level functions (e.g. URL -> System.FilePath),
  // but defined as part of URLToFilePathError.

  /// The path created from the URL could not be transcoded to the system's encoding.
  ///
  /// File URLs can preserve the precise bytes of their path components by means of percent-encoding.
  /// However, when the platform's native path representation uses non-8-bit code-units, those elements must be transcoded
  /// from the percent-encoded 8-bit values to the system's native encoding.
  ///
  @inlinable
  public static var transcodingFailure: URLToFilePathError {
    URLToFilePathError(.transcodingFailure)
  }

  public var description: String {
    switch _err {
    case .notAFileURL: return "Not a file URL"
    case .encodedPathSeparator: return "Percent-encoded path separator"
    case .encodedNullBytes: return "Percent-encoded NULL bytes"
    case .posixPathsCannotContainHosts: return "Hostnames are unsupported by POSIX paths"
    case .windowsPathIsNotFullyQualified: return "Not a fully-qualified Windows path"
    case .transcodingFailure: return "Transcoding failure"
    }
  }
}

/// Creates a POSIX path from a `file:` URL.
///
/// The result is a string of opaque bytes, reflecting the bytes encoded in the URL. The returned bytes are not null-terminated.
///
@usableFromInline
internal func _urlToFilePath_posix(
  _ url: WebURL, nullTerminated: Bool
) -> Result<ContiguousArray<UInt8>, URLToFilePathError> {

  guard case .file = url.schemeKind else {
    return .failure(.notAFileURL)
  }
  guard url.utf8.hostname!.isEmpty else {
    return .failure(.posixPathsCannotContainHosts)
  }

  var filePath = ContiguousArray<UInt8>()
  filePath.reserveCapacity(url.utf8.path.count)

  // Percent-decode the path, including control characters and invalid UTF-8 byte sequences.
  // Do not decode characters which are interpreted by the filesystem and would meaningfully alter the path.
  // For POSIX, that means 0x00 and 0x2F. Pct-encoded periods are already interpreted by the URL parser.

  for i in url.utf8.path.lazy.percentDecodedUTF8.indices {
    if i.isDecoded {
      if i.decodedValue == ASCII.null.codePoint {
        return .failure(.encodedNullBytes)
      }
      if i.decodedValue == ASCII.forwardSlash.codePoint {
        return .failure(.encodedPathSeparator)
      }
    } else {
      assert(i.decodedValue != ASCII.null.codePoint, "Non-percent-encoded NULL byte in URL path")
    }
    filePath.append(i.decodedValue)
  }

  // Normalization.
  // Collapse multiple path slashes into a single slash, except if a leading double slash ("//usr/bin").
  // POSIX says that leading double slashes are implementation-defined.

  precondition(filePath[0] == ASCII.forwardSlash.codePoint, "URL has invalid path")

  if filePath.count > 2 {
    if filePath[1] == ASCII.forwardSlash.codePoint, filePath[2] != ASCII.forwardSlash.codePoint {
      filePath.collapseForwardSlashes(from: 2)
    } else {
      filePath.collapseForwardSlashes(from: 0)
    }
  }

  // Null-termination (if requested).

  if nullTerminated {
    filePath.append(0)
  }

  assert(!filePath.isEmpty)
  return .success(filePath)
}

/// Creates a Windows path from a `file:` URL.
///
/// The result is a string of kind-of-opaque bytes, reflecting the bytes encoded in the URL.
/// It is more reasonable to assume that Windows paths will be UTF-8 encoded, although that may not always be the case.
/// The returned bytes are not null-terminated.
///
@usableFromInline
internal func _urlToFilePath_windows(
  _ url: WebURL, nullTerminated: Bool
) -> Result<ContiguousArray<UInt8>, URLToFilePathError> {

  guard case .file = url.schemeKind else {
    return .failure(.notAFileURL)
  }

  let isUNC = (url.utf8.hostname!.isEmpty == false)
  var urlPath = url.utf8.path
  precondition(urlPath.first == ASCII.forwardSlash.codePoint, "URL has invalid path")

  if !isUNC {
    // For DOS-style paths, the first component must be a drive letter and be followed by another component.
    // (e.g. "/C:/" is okay, "/C:" is not). Furthermore, we require the drive letter not be percent-encoded.

    // This may be too strict - people sometimes over-escape characters in URLs, and generally standards favour
    // treating percent-encoded characters as equivalent to their decoded versions.
    let drive = url.utf8.pathComponent(url.pathComponents.startIndex)
    guard PathComponentParser.isNormalizedWindowsDriveLetter(drive), drive.endIndex < urlPath.endIndex else {
      return .failure(.windowsPathIsNotFullyQualified)
    }
    // Drop the leading slash from the path.
    urlPath.removeFirst()
    assert(urlPath.startIndex == drive.startIndex)
  }

  // Percent-decode the path, including control characters and invalid UTF-8 byte sequences.
  // Do not decode characters which are interpreted by the filesystem and would meaningfully alter the path.
  // For Windows, that means 0x00, 0x2F, and 0x5C. Pct-encoded periods are already interpreted by the URL parser.

  var filePath = ContiguousArray<UInt8>()
  filePath.reserveCapacity(url.utf8.path.count)

  for i in urlPath.lazy.percentDecodedUTF8.indices {
    if i.isDecoded {
      if i.decodedValue == ASCII.null.codePoint {
        return .failure(.encodedNullBytes)
      }
      if isWindowsFilePathSeparator(i.decodedValue) {
        return .failure(.encodedPathSeparator)
      }
    }
    filePath.append(i.decodedValue)
  }

  assert(!filePath.isEmpty)
  assert((filePath.first == ASCII.forwardSlash.codePoint) == isUNC)

  // Normalization.
  // At this point, we should only be using forward slashes since the path came from the URL,
  // so collapse them and replace with back slashes.

  assert(!filePath.contains(ASCII.backslash.codePoint))

  filePath.collapseForwardSlashes(from: 0)
  filePath.trimPathSegmentsForWindows(from: 0, isUNC: isUNC)
  for i in 0..<filePath.count {
    if filePath[i] == ASCII.forwardSlash.codePoint {
      filePath[i] = ASCII.backslash.codePoint
    }
  }

  assert(!filePath.isEmpty)
  assert((filePath.first == ASCII.backslash.codePoint) == isUNC)

  // Prepend the UNC server name.

  if isUNC {
    let hostname = url.utf8.hostname!
    assert(!hostname.contains(ASCII.percentSign.codePoint), "file URL hostnames cannot contain percent-encoding")

    if hostname.first == ASCII.leftSquareBracket.codePoint {
      // IPv6 hostnames must be transcribed for UNC:
      // https://en.wikipedia.org/wiki/IPv6_address#Literal_IPv6_addresses_in_UNC_path_names
      assert(hostname.last == ASCII.rightSquareBracket.codePoint, "Invalid hostname")
      assert(IPv6Address(utf8: hostname.dropFirst().dropLast()) != nil, "Invalid IPv6 hostname")

      var transcribedHostAndPrefix = ContiguousArray(#"\\"#.utf8)
      transcribedHostAndPrefix += hostname.dropFirst().dropLast().lazy.map { codePoint in
        codePoint == ASCII.colon.codePoint ? ASCII.minus.codePoint : codePoint
      }
      transcribedHostAndPrefix += ".ipv6-literal.net".utf8
      filePath.insert(contentsOf: transcribedHostAndPrefix, at: 0)
    } else {
      filePath.insert(contentsOf: hostname, at: 0)
      filePath.insert(contentsOf: #"\\"#.utf8, at: 0)
    }
  }

  // Null-termination (if requested).

  if nullTerminated {
    filePath.append(0)
  }

  return .success(filePath)
}


// --------------------------------------------
// MARK: - Utilities
// --------------------------------------------


/// The URL `file:///` - the simplest valid file URL, consisting of an empty hostname and a root path.
///
@inlinable
internal var _emptyFileURL: WebURL {
  WebURL(
    storage: AnyURLStorage(
      URLStorage<BasicURLHeader<UInt8>>(
        count: 8,
        structure: URLStructure(
          schemeLength: 5, usernameLength: 0, passwordLength: 0, hostnameLength: 0,
          portLength: 0, pathLength: 1, queryLength: 0, fragmentLength: 0, firstPathComponentLength: 1,
          sigil: .authority, schemeKind: .file, cannotBeABaseURL: false, queryIsKnownFormEncoded: true),
        initializingCodeUnitsWith: { buffer in
          ("file:///" as StaticString).withUTF8Buffer { buffer.fastInitialize(from: $0) }
        }
      )
    ))
}

extension PercentEncodeSet {

  /// A percent-encode set for Windows DOS-style path components, as well as UNC share names and UNC path components.
  ///
  /// This set encodes ASCII codepoints which may occur in the Windows path components, but have special meaning in a URL string.
  /// The set does not include the 'path' encode-set, as some codepoints must stay in their original form for trimming (e.g. spaces, periods).
  ///
  /// Note that the colon character (`:`) is also included, so this encode-set is not appropriate for Windows drive letter components.
  /// Drive letters should not be percent-encoded.
  ///
  @usableFromInline
  internal struct WindowsPathPercentEncoder: PercentEncodeSetProtocol {
    // swift-format-ignore
    @inlinable
    internal static func shouldPercentEncode(ascii codePoint: UInt8) -> Bool {
      // Encode:
      // - The `%` sign itself. Filesystem paths do not contain percent-encoding, and any character seqeuences which
      //   look like percent-encoding are just coincidences.
      codePoint == ASCII.percentSign.codePoint
      // - Colons (`:`). These are interpreted as Windows drive letter delimiters; but *actual* drive letters
      //   are detected by the file-path-to-URL function and not encoded. Any other components that look
      //   like drive letters are coincidences.
      || codePoint == ASCII.colon.codePoint
      // - Vertical bars (`|`). These are sometimes interpreted as Windows drive delimiters in URL paths
      //   and relative references, but not by Windows in filesystem paths.
      || codePoint == ASCII.verticalBar.codePoint
    }
  }

  /// A percent-encode set for POSIX-style path components.
  ///
  /// This set encodes ASCII codepoints which may occur in the path components of a POSIX-style path, but have special meaning in a URL string.
  /// The set includes the codepoints of the 'path' encode-set, as the components of POSIX paths are not trimmed.
  ///
  @usableFromInline
  internal struct POSIXPathPercentEncoder: PercentEncodeSetProtocol {
    // swift-format-ignore
    @inlinable
    internal static func shouldPercentEncode(ascii codePoint: UInt8) -> Bool {
      // Encode:
      // - The '%' sign itself. Filesystem paths do not contain percent-encoding, and any character seqeuences which
      //   look like percent-encoding are just coincidences.
      codePoint == ASCII.percentSign.codePoint
      // - Backslashes (`\`). They are allowed in POSIX paths and are not separators.
      || codePoint == ASCII.backslash.codePoint
      // - Colons (`:`) and vertical bars (`|`). These are sometimes interpreted as Windows drive letter delimiters,
      //   which POSIX paths obviously do not have.
      || codePoint == ASCII.colon.codePoint || codePoint == ASCII.verticalBar.codePoint
      // - The entire 'path' percent-encode set. The path setter will check this and do it as well, but we can
      //   make things more efficient by correctly encoding the path in the first place.
      //   Since POSIX path components are not trimmed, we don't need to avoid encoding things like spaces or periods.
      || PercentEncodeSet.Path.shouldPercentEncode(ascii: codePoint)
    }
  }

  @usableFromInline
  internal var windowsPath: WindowsPathPercentEncoder.Type { WindowsPathPercentEncoder.self }

  @usableFromInline
  internal var posixPath: POSIXPathPercentEncoder.Type { POSIXPathPercentEncoder.self }
}

/// Whether the given code-unit, which is assumed to be in a Windows 'filesystem-safe' encoding, is considered a path separator on Windows.
///
@inlinable
internal func isWindowsFilePathSeparator(_ codeUnit: UInt8) -> Bool {
  ASCII(codeUnit) == .forwardSlash || ASCII(codeUnit) == .backslash
}

extension Collection where Element == UInt8 {

  /// Whether this collection, when split by elements matching the given `isSeparator` closure, contains any segments
  /// that consist of the ASCII string ".." only ([0x2E, 0x2E]).
  ///
  @inlinable
  internal func containsLiteralDotDotComponent(isSeparator: (UInt8) -> Bool) -> Bool {
    (".." as StaticString).withUTF8Buffer { dotdot in
      var componentStart = startIndex
      while let separatorIndex = self[componentStart...].firstIndex(where: isSeparator) {
        guard !self[componentStart..<separatorIndex].elementsEqual(dotdot) else {
          return true
        }
        componentStart = index(after: separatorIndex)
      }
      guard !self[componentStart...].elementsEqual(dotdot) else {
        return true
      }
      return false
    }
  }
}

extension BidirectionalCollection where Self: MutableCollection, Self: RangeReplaceableCollection, Element == UInt8 {

  /// Replaces runs of 2 or more ASCII forward slashes (0x2F) with a single forward slash, starting at the given index.
  ///
  @inlinable
  internal mutating func collapseForwardSlashes(from start: Index) {
    let end = collapseConsecutiveElements(from: start) { $0 == ASCII.forwardSlash.codePoint }
    removeSubrange(end...)
  }

  /// Replaces runs of 2 or more Windows path separators with a single separator, starting at the given index.
  /// For each run of separators, the first separator is kept.
  ///
  @inlinable
  internal mutating func collapseWindowsPathSeparators(from start: Index) {
    let end = collapseConsecutiveElements(from: start) { isWindowsFilePathSeparator($0) }
    removeSubrange(end...)
  }

  /// Splits the collection's contents in to segments at Windows path separators, from the given index,
  /// and trims each segment according to Windows' documented path normalization rules.
  ///
  /// If the path is a UNC path (`isUNC` is `true`), the first component is interpreted as a UNC share name and is not trimmed.
  ///
  @inlinable
  internal mutating func trimPathSegmentsForWindows(from start: Index, isUNC: Bool) {
    let end = trimSegments(from: start, separatedBy: isWindowsFilePathSeparator) { component, isFirst, isLast in
      guard !(isUNC && isFirst) else {
        // The first component is the share name. IE and Windows Explorer appear to have a bug and trim these,
        // but GetFullPathName, Edge, and Chrome do not.
        // https://github.com/dotnet/docs/issues/24563
        return component
      }

      // Windows path component trimming:
      //
      // - If a segment ends in a single period, that period is removed.
      //   (A segment of a single or double period is normalized in the previous step.
      //    A segment of three or more periods is not normalized and is actually a valid file/directory name.)
      // - If the path doesn't end in a separator, all trailing periods and spaces (U+0020) are removed.
      //   If the last segment is simply a single or double period, it falls under the relative components rule above.
      //   This rule means that you can create a directory name with a trailing space by adding
      //   a trailing separator after the space.
      //
      //   Source: https://docs.microsoft.com/en-us/dotnet/standard/io/file-path-formats#trim-characters

      // Single-dot-components will be normalized by the URL path parser.
      if component.elementsEqual(CollectionOfOne(ASCII.period.codePoint)) {
        return component
      }
      // Double-dot-components should have been rejected already.
      assert(!component.elementsEqual(repeatElement(ASCII.period.codePoint, count: 2)))

      if isLast {
        // Trim all dots and spaces, even if it leaves the component empty.
        let charactersToTrim = component.suffix { $0 == ASCII.period.codePoint || $0 == ASCII.space.codePoint }
        return component[component.startIndex..<charactersToTrim.startIndex]
      } else {
        // If the component ends with <non-dot><dot>, trim the trailing dot.
        if component.last == ASCII.period.codePoint {
          let trimmedComponent = component.dropLast()
          assert(!trimmedComponent.isEmpty)
          if trimmedComponent.last != ASCII.period.codePoint {
            return trimmedComponent
          }
        }
        // Otherwise, nothing to trim; we're done.
        return component
      }
    }
    removeSubrange(end...)
  }
}
