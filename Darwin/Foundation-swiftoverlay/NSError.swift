import Foundation
import CoreFoundation
import Darwin

// NSError and CFError conform to the standard ErrorType protocol. Compiler
// magic allows this to be done as a "toll-free" conversion when an NSError
// or CFError is used as an ErrorType existential.

extension NSError : ErrorType {
  public var _domain: String { return domain }
  public var _code: Int { return code }
}

extension CFError : ErrorType {
  public var _domain: String {
    return CFErrorGetDomain(self) as String
  }

  public var _code: Int {
    return CFErrorGetCode(self)
  }
}

// An error value to use when an Objective-C API indicates error
// but produces a nil error object.
public enum _GenericObjCError : ErrorType {
  case NilError
}

/// An intrinsic used by the runtime to create an error when an
/// Objective-C API indicates failure but produces a nil error.
@asmname("_swift_allocNilObjCError")
func _allocNilObjCError() -> ErrorType {
  return _GenericObjCError.NilError
}

/// An internal protocol to represent Swift error enums that map to standard
/// Cocoa NSError domains.
public protocol _ObjectiveCBridgeableErrorType : ErrorType {
  /// Produce a value of the error type corresponding to the given NSError,
  /// or return nil if it cannot be bridged.
  init?(_bridgedNSError: NSError)
}

/// A hook for the runtime to use _ObjectiveCBridgeableErrorType in order to
/// attempt an "errorTypeValue as? SomeError" cast.
///
/// If the bridge succeeds, the bridged value is written to the uninitialized
/// memory pointed to by 'out', and true is returned. Otherwise, 'out' is
/// left uninitialized, and false is returned.
@asmname("swift_stdlib_bridgeNSErrorToErrorType")
public func _stdlib_bridgeNSErrorToErrorType<
  T : _ObjectiveCBridgeableErrorType
>(error: NSError, out: UnsafeMutablePointer<T>) -> Bool {
  if let bridged = T(_bridgedNSError: error) {
    out.initialize(bridged)
    return true
  } else {
    return false
  }
}

/// Helper protocol for _BridgedNSError, which used used to provide
/// default implementations.
public protocol __BridgedNSError : RawRepresentable {
  static var _NSErrorDomain: String { get }
}

// Allow two bridged NSError types to be compared.
public func ==<T: __BridgedNSError where T.RawValue: SignedIntegerType>(
  lhs: T,
  rhs: T
) -> Bool {
  return lhs.rawValue.toIntMax() == rhs.rawValue.toIntMax()
}

public extension __BridgedNSError where RawValue: SignedIntegerType {
  public final var _domain: String { return Self._NSErrorDomain }
  public final var _code: Int { return Int(rawValue.toIntMax()) }

  public init?(rawValue: RawValue) {
    self = unsafeBitCast(rawValue, Self.self)
  }

  public init?(_bridgedNSError: NSError) {
    if _bridgedNSError.domain != Self._NSErrorDomain {
      return nil
    }

    self.init(rawValue: RawValue(IntMax(_bridgedNSError.code)))
  }

  public final var hashValue: Int { return _code }
}

#if false
// Allow two bridged NSError types to be compared.
public func ==<T: __BridgedNSError where T.RawValue: UnsignedIntegerType>(
  lhs: T,
  rhs: T
) -> Bool {
  return lhs.rawValue.toUIntMax() == rhs.rawValue.toUIntMax()
}


// rdar://problem/21027215 prevents this
public extension __BridgedNSError where RawValue: UnsignedIntegerType {
  public final var _domain: String { return Self._NSErrorDomain }
  public final var _code: Int {
    return Int(bitPattern: UInt(rawValue.toUIntMax()))
  }

  public init?(rawValue: RawValue) {
    self = unsafeBitCast(rawValue, Self.self)
  }

  public init?(_bridgedNSError: NSError) {
    if _bridgedNSError.domain != Self._NSErrorDomain {
      return nil
    }

    self.init(rawValue: RawValue(UIntMax(UInt(_bridgedNSError.code))))
  }

  public final var hashValue: Int { return _code }
}
#endif

/// Describes a raw representable type that is bridged to a particular
/// NSError domain.
///
/// This protocol is used primarily to generate the conformance to
/// _ObjectiveCBridgeableErrorType for such an enum.
public protocol _BridgedNSError : __BridgedNSError,
                                  _ObjectiveCBridgeableErrorType,
                                  Hashable {
  /// The NSError domain to which this type is bridged.
  static var _NSErrorDomain: String { get }
}

/// Enumeration that describes the error codes within the Cocoa error
/// domain.
public struct NSCocoaError : RawRepresentable, _BridgedNSError {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static var _NSErrorDomain: String { return NSCocoaErrorDomain }
}

public func ~=(match: NSCocoaError, error: ErrorType) -> Bool {
  guard let cocoaError = error as? NSCocoaError else { return false }
  return match.rawValue == cocoaError.rawValue
}

public extension NSCocoaError {
  static let FileNoSuchFileError = NSCocoaError(rawValue: 4)
  static let FileLockingError = NSCocoaError(rawValue: 255)
  static let FileReadUnknownError = NSCocoaError(rawValue: 256)
  static let FileReadNoPermissionError = NSCocoaError(rawValue: 257)
  static let FileReadInvalidFileNameError = NSCocoaError(rawValue: 258)
  static let FileReadCorruptFileError = NSCocoaError(rawValue: 259)
  static let FileReadNoSuchFileError = NSCocoaError(rawValue: 260)
  static let FileReadInapplicableStringEncodingError = NSCocoaError(rawValue: 261)
  static let FileReadUnsupportedSchemeError = NSCocoaError(rawValue: 262)

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  static let FileReadTooLargeError = NSCocoaError(rawValue: 263)

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  static let FileReadUnknownStringEncodingError = NSCocoaError(rawValue: 264)

  static let FileWriteUnknownError = NSCocoaError(rawValue: 512)
  static let FileWriteNoPermissionError = NSCocoaError(rawValue: 513)
  static let FileWriteInvalidFileNameError = NSCocoaError(rawValue: 514)

  @available(OSX, introduced=10.7) @available(iOS, introduced=5.0)
  static let FileWriteFileExistsError = NSCocoaError(rawValue: 516)

  static let FileWriteInapplicableStringEncodingError = NSCocoaError(rawValue: 517)
  static let FileWriteUnsupportedSchemeError = NSCocoaError(rawValue: 518)
  static let FileWriteOutOfSpaceError = NSCocoaError(rawValue: 640)

  @available(OSX, introduced=10.6) @available(iOS, introduced=4.0)
  static let FileWriteVolumeReadOnlyError = NSCocoaError(rawValue: 642)

  @available(OSX, introduced=10.11) @available(iOS, unavailable)
  static let FileManagerUnmountUnknownError = NSCocoaError(rawValue: 768)

  @available(OSX, introduced=10.11) @available(iOS, unavailable)
  static let FileManagerUnmountBusyError = NSCocoaError(rawValue: 769)

  static let KeyValueValidationError = NSCocoaError(rawValue: 1024)
  static let FormattingError = NSCocoaError(rawValue: 2048)
  static let UserCancelledError = NSCocoaError(rawValue: 3072)

  @available(OSX, introduced=10.8) @available(iOS, introduced=6.0)
  static let FeatureUnsupportedError = NSCocoaError(rawValue: 3328)

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  static let ExecutableNotLoadableError = NSCocoaError(rawValue: 3584)

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  static let ExecutableArchitectureMismatchError = NSCocoaError(rawValue: 3585)

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  static let ExecutableRuntimeMismatchError = NSCocoaError(rawValue: 3586)

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  static let ExecutableLoadError = NSCocoaError(rawValue: 3587)

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  static let ExecutableLinkError = NSCocoaError(rawValue: 3588)

  @available(OSX, introduced=10.6) @available(iOS, introduced=4.0)
  static let PropertyListReadCorruptError = NSCocoaError(rawValue: 3840)

  @available(OSX, introduced=10.6) @available(iOS, introduced=4.0)
  static let PropertyListReadUnknownVersionError = NSCocoaError(rawValue: 3841)

  @available(OSX, introduced=10.6) @available(iOS, introduced=4.0)
  static let PropertyListReadStreamError = NSCocoaError(rawValue: 3842)

  @available(OSX, introduced=10.6) @available(iOS, introduced=4.0)
  static let PropertyListWriteStreamError = NSCocoaError(rawValue: 3851)

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  static let PropertyListWriteInvalidError = NSCocoaError(rawValue: 3852)

  @available(OSX, introduced=10.8) @available(iOS, introduced=6.0)
  static let XPCConnectionInterrupted = NSCocoaError(rawValue: 4097)

  @available(OSX, introduced=10.8) @available(iOS, introduced=6.0)
  static let XPCConnectionInvalid = NSCocoaError(rawValue: 4099)

  @available(OSX, introduced=10.8) @available(iOS, introduced=6.0)
  static let XPCConnectionReplyInvalid = NSCocoaError(rawValue: 4101)

  @available(OSX, introduced=10.9) @available(iOS, introduced=7.0)
  static let UbiquitousFileUnavailableError = NSCocoaError(rawValue: 4353)

  @available(OSX, introduced=10.9) @available(iOS, introduced=7.0)
  static let UbiquitousFileNotUploadedDueToQuotaError = NSCocoaError(rawValue: 4354)

  @available(OSX, introduced=10.9) @available(iOS, introduced=7.0)
  static let UbiquitousFileUbiquityServerNotAvailable = NSCocoaError(rawValue: 4355)

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  static let UserActivityHandoffFailedError = NSCocoaError(rawValue: 4608)

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  static let UserActivityConnectionUnavailableError = NSCocoaError(rawValue: 4609)

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  static let UserActivityRemoteApplicationTimedOutError = NSCocoaError(rawValue: 4610)

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  static let UserActivityHandoffUserInfoTooLargeError = NSCocoaError(rawValue: 4611)

  @available(OSX, introduced=10.11) @available(iOS, introduced=9.0)
  static let CoderReadCorruptError = NSCocoaError(rawValue: 4864)

  @available(OSX, introduced=10.11) @available(iOS, introduced=9.0)
  static let CoderValueNotFoundError = NSCocoaError(rawValue: 4865)


  @available(OSX, introduced=10.11) @available(iOS, introduced=9.0)
  public var isCoderError: Bool {
    return rawValue >= 4864 && rawValue <= 4991;
  }

  @available(OSX, introduced=10.5) @available(iOS, introduced=2.0)
  public var isExecutableError: Bool {
    return rawValue >= 3584 && rawValue <= 3839;
  }

  public var isFileError: Bool {
    return rawValue >= 0 && rawValue <= 1023;
  }

  public var isFormattingError: Bool {
    return rawValue >= 2048 && rawValue <= 2559;
  }

  @available(OSX, introduced=10.6) @available(iOS, introduced=4.0)
  public var isPropertyListError: Bool {
    return rawValue >= 3840 && rawValue <= 4095;
  }

  @available(OSX, introduced=10.9) @available(iOS, introduced=7.0)
  public var isUbiquitousFileError: Bool {
    return rawValue >= 4352 && rawValue <= 4607;
  }

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  public var isUserActivityError: Bool {
    return rawValue >= 4608 && rawValue <= 4863;
  }

  public var isValidationError: Bool {
    return rawValue >= 1024 && rawValue <= 2047;
  }

  @available(OSX, introduced=10.8) @available(iOS, introduced=6.0)
  public var isXPCConnectionError: Bool {
    return rawValue >= 4096 && rawValue <= 4224;
  }
}

/// Enumeration that describes the error codes within the NSURL error
/// domain.
@objc public enum NSURLError : Int, _BridgedNSError {
  case Unknown = -1
  case Cancelled = -999
  case BadURL = -1000
  case TimedOut = -1001
  case UnsupportedURL = -1002
  case CannotFindHost = -1003
  case CannotConnectToHost = -1004
  case NetworkConnectionLost = -1005
  case DNSLookupFailed = -1006
  case HTTPTooManyRedirects = -1007
  case ResourceUnavailable = -1008
  case NotConnectedToInternet = -1009
  case RedirectToNonExistentLocation = -1010
  case BadServerResponse = -1011
  case UserCancelledAuthentication = -1012
  case UserAuthenticationRequired = -1013
  case ZeroByteResource = -1014
  case CannotDecodeRawData = -1015
  case CannotDecodeContentData = -1016
  case CannotParseResponse = -1017
  case FileDoesNotExist = -1100
  case FileIsDirectory = -1101
  case NoPermissionsToReadFile = -1102
  case SecureConnectionFailed = -1200
  case ServerCertificateHasBadDate = -1201
  case ServerCertificateUntrusted = -1202
  case ServerCertificateHasUnknownRoot = -1203
  case ServerCertificateNotYetValid = -1204
  case ClientCertificateRejected = -1205
  case ClientCertificateRequired = -1206
  case CannotLoadFromNetwork = -2000
  case CannotCreateFile = -3000
  case CannotOpenFile = -3001
  case CannotCloseFile = -3002
  case CannotWriteToFile = -3003
  case CannotRemoveFile = -3004
  case CannotMoveFile = -3005
  case DownloadDecodingFailedMidStream = -3006
  case DownloadDecodingFailedToComplete = -3007

  @available(OSX, introduced=10.7) @available(iOS, introduced=3.0)
  case InternationalRoamingOff = -1018

  @available(OSX, introduced=10.7) @available(iOS, introduced=3.0)
  case CallIsActive = -1019

  @available(OSX, introduced=10.7) @available(iOS, introduced=3.0)
  case DataNotAllowed = -1020

  @available(OSX, introduced=10.7) @available(iOS, introduced=3.0)
  case RequestBodyStreamExhausted = -1021

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  case BackgroundSessionRequiresSharedContainer = -995

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  case BackgroundSessionInUseByAnotherProcess = -996

  @available(OSX, introduced=10.10) @available(iOS, introduced=8.0)
  case BackgroundSessionWasDisconnected = -997

  public static var _NSErrorDomain: String { return NSURLErrorDomain }
}

extension POSIXError : _BridgedNSError {
  public static var _NSErrorDomain: String { return NSPOSIXErrorDomain }
}

extension MachError : _BridgedNSError {
  public static var _NSErrorDomain: String { return NSMachErrorDomain }
}
