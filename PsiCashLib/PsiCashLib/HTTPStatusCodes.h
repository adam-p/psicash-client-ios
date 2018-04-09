//
//  HTTPStatusCodes.h
//  PsiCashLib
//

#ifndef HTTPStatusCodes_h
#define HTTPStatusCodes_h

// Adapted from Golang's net/http/status.go

extern NSInteger const kHTTPStatusContinue;
extern NSInteger const kHTTPStatusSwitchingProtocols;
extern NSInteger const kHTTPStatusProcessing;

extern NSInteger const kHTTPStatusOK;
extern NSInteger const kHTTPStatusCreated;
extern NSInteger const kHTTPStatusAccepted;
extern NSInteger const kHTTPStatusNonAuthoritativeInfo;
extern NSInteger const kHTTPStatusNoContent;
extern NSInteger const kHTTPStatusResetContent;
extern NSInteger const kHTTPStatusPartialContent;
extern NSInteger const kHTTPStatusMultiStatus;
extern NSInteger const kHTTPStatusAlreadyReported;
extern NSInteger const kHTTPStatusIMUsed;

extern NSInteger const kHTTPStatusMultipleChoices;
extern NSInteger const kHTTPStatusMovedPermanently;
extern NSInteger const kHTTPStatusFound;
extern NSInteger const kHTTPStatusSeeOther;
extern NSInteger const kHTTPStatusNotModified;
extern NSInteger const kHTTPStatusUseProxy;
extern NSInteger const kHTTPStatus306;
extern NSInteger const kHTTPStatusTemporaryRedirect;
extern NSInteger const kHTTPStatusPermanentRedirect;

extern NSInteger const kHTTPStatusBadRequest;
extern NSInteger const kHTTPStatusUnauthorized;
extern NSInteger const kHTTPStatusPaymentRequired;
extern NSInteger const kHTTPStatusForbidden;
extern NSInteger const kHTTPStatusNotFound;
extern NSInteger const kHTTPStatusMethodNotAllowed;
extern NSInteger const kHTTPStatusNotAcceptable;
extern NSInteger const kHTTPStatusProxyAuthRequired;
extern NSInteger const kHTTPStatusRequestTimeout;
extern NSInteger const kHTTPStatusConflict;
extern NSInteger const kHTTPStatusGone;
extern NSInteger const kHTTPStatusLengthRequired;
extern NSInteger const kHTTPStatusPreconditionFailed;
extern NSInteger const kHTTPStatusRequestEntityTooLarge;
extern NSInteger const kHTTPStatusRequestURITooLong;
extern NSInteger const kHTTPStatusUnsupportedMediaType;
extern NSInteger const kHTTPStatusRequestedRangeNotSatisfiable;
extern NSInteger const kHTTPStatusExpectationFailed;
extern NSInteger const kHTTPStatusTeapot;
extern NSInteger const kHTTPStatusUnprocessableEntity;
extern NSInteger const kHTTPStatusLocked;
extern NSInteger const kHTTPStatusFailedDependency;
extern NSInteger const kHTTPStatusUpgradeRequired;
extern NSInteger const kHTTPStatusPreconditionRequired;
extern NSInteger const kHTTPStatusTooManyRequests;
extern NSInteger const kHTTPStatusRequestHeaderFieldsTooLarge;
extern NSInteger const kHTTPStatusUnavailableForLegalReasons;

extern NSInteger const kHTTPStatusInternalServerError;
extern NSInteger const kHTTPStatusNotImplemented;
extern NSInteger const kHTTPStatusBadGateway;
extern NSInteger const kHTTPStatusServiceUnavailable;
extern NSInteger const kHTTPStatusGatewayTimeout;
extern NSInteger const kHTTPStatusHTTPVersionNotSupported;
extern NSInteger const kHTTPStatusVariantAlsoNegotiates;
extern NSInteger const kHTTPStatusInsufficientStorage;
extern NSInteger const kHTTPStatusLoopDetected;
extern NSInteger const kHTTPStatusNotExtended;
extern NSInteger const kHTTPStatusNetworkAuthenticationRequired;

#endif /* HTTPStatusCodes_h */

