//
//  PsiCash.m
//  PsiCashLib
//

#import "PsiCash.h"
#import "NSError+NSErrorExt.h"
#import "UserIdentity.h"
#import "HTTPStatusCodes.h"

/* TODO
 - Consider using NSUbiquitousKeyValueStore instead of NSUserDefaults for
 cross-device synchronized storage. (Not using it for now because it introduces
 complexity.)
 - Have init() take a queue on which the completion calls should be made? (Like
   PsiphonTunnel does.)
 */

/*
NOTES
 - Methods like getBalance are specifically not checking if authTokens have been
   properly populated before trying to use them. We (probably?) don't want to call
   the completion block on the queue that is calling our method, so we'll let the
   request attempt go through and fail with "401 Authorization Required", at which
   point the completion block will be called. This shouldn't happen anyway, as it
   indicates an incorrect use of the library.
 - See the note at the bottom of this file about proxy support.
*/

NSString * const PSICASH_SERVER_SCHEME = @"http"; // @"https"; // TODO
NSString * const PSICASH_SERVER_HOSTNAME = @"127.0.0.1"; // TODO
int const PSICASH_SERVER_PORT = 51337; // 443; // TODO
NSTimeInterval const TIMEOUT_SECS = 100.0; // TODO Probably longer than the server timeout.
NSString * const AUTH_HEADER = @"X-PsiCash-Auth";
NSUInteger const REQUEST_RETRY_LIMIT = 2;

@implementation PsiCashPurchasePrice
@end

@implementation PsiCash {
    UserIdentity *userID;
}

# pragma mark - Init

- (id)init
{
    // authTokens may still be nil if the value has never been stored.
    self->userID = [[UserIdentity alloc] init];

    return self;
}

#pragma mark - GetBalance

- (void)getBalance:(void (^_Nonnull)(PsiCashRequestStatus status,
                                     NSNumber*_Nullable balance,
                                     NSError*_Nullable error))completionHandler
{
    NSMutableURLRequest *request = [PsiCash createRequestFor:@"/balance"
                                                  withMethod:@"GET"
                                              withQueryItems:nil
                                              withAuthTokens:self->userID.authTokens];

    [self doRequestWithRetry:request
                    useCache:NO
             numberOfRetries:REQUEST_RETRY_LIMIT
           completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {

        if (error) {
            error = [NSError errorWrapping:error withMessage:@"request error" fromFunction:__FUNCTION__];
            completionHandler(kInvalid, nil, error);
            return;
        }

        if (response.statusCode == kHTTPStatusOK) {
            if (!data) {
                error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                completionHandler(kInvalid, nil, error);
                return;
            }

           NSNumber* balance;
           BOOL isAccount;
           [PsiCash parseGetBalanceResponse:data balance:&balance isAccount:&isAccount withError:&error];
           if (error != nil) {
                error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                completionHandler(kInvalid, nil, error);
                return;
           }

           self->userID.isAccount = isAccount;

           completionHandler(kSuccess, balance, nil);
           return;
        }
        else if (response.statusCode == kHTTPStatusUnauthorized) {
            completionHandler(kInvalidTokens, nil, nil);
            return;
        }
        else if (response.statusCode == kHTTPStatusInternalServerError) {
            completionHandler(kServerError, nil, nil);
            return;
        }
        else {
            error = [NSError errorWithMessage:[NSString stringWithFormat:@"request failure: %ld", response.statusCode]
                                 fromFunction:__FUNCTION__];
            completionHandler(kInvalid, nil, error);
            return;
        }
    }];
}

+ (void)parseGetBalanceResponse:(NSData*)jsonData balance:(NSNumber**)balance isAccount:(BOOL*)isAccount withError:(NSError**)error
{
    *error = nil;
    *balance = 0;
    *isAccount = NO;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization error" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    // Note: isKindOfClass is false if the key isn't found

    if (![data[@"Balance"] isKindOfClass:NSNumber.class]) {
        *error = [NSError errorWithMessage:@"Balance is not a number" fromFunction:__FUNCTION__];
        return;
    }
    *balance = data[@"Balance"];

    if (![data[@"IsAccount"] isKindOfClass:NSNumber.class]) {
        *error = [NSError errorWithMessage:@"IsAccount is not a number" fromFunction:__FUNCTION__];
        return;
    }
    *isAccount = [(NSNumber*)data[@"IsAccount"] boolValue];
}

#pragma mark - GetPurchasePrices

- (void)getPurchasePricesForClasses:(NSArray*_Nonnull)classes
                  completionHandler:(void (^_Nonnull)(PsiCashRequestStatus status,
                                                      NSArray*_Nullable purchasePrices,
                                                      NSError*_Nullable error))completionHandler
{
    NSMutableArray *queryItems = [NSMutableArray new];
    for (NSString *val in classes) {
        NSURLQueryItem *qi = [NSURLQueryItem queryItemWithName:@"class" value:val];
        [queryItems addObject:qi];
    }

    NSMutableURLRequest *request = [PsiCash createRequestFor:@"/purchase-prices"
                                                  withMethod:@"GET"
                                              withQueryItems:queryItems
                                              withAuthTokens:self->userID.authTokens];

    [self doRequestWithRetry:request
                    useCache:YES
             numberOfRetries:REQUEST_RETRY_LIMIT
           completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error)
    {
       if (error) {
           error = [NSError errorWrapping:error withMessage:@"request error" fromFunction:__FUNCTION__];
           completionHandler(kInvalid, nil, error);
           return;
       }

       if (response.statusCode == kHTTPStatusOK) {
           if (!data) {
               error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
               completionHandler(kInvalid, nil, error);
               return;
           }

           NSArray* purchasePrices;
           [PsiCash parseGetPurchasePricesResponse:data purchasePrices:&purchasePrices withError:&error];
           if (error != nil) {
               error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
               completionHandler(kInvalid, nil, error);
               return;
           }

           completionHandler(kSuccess, purchasePrices, nil);
           return;
       }
       else if (response.statusCode == kHTTPStatusUnauthorized) {
           completionHandler(kInvalidTokens, nil, nil);
           return;
       }
       else if (response.statusCode == kHTTPStatusInternalServerError) {
           completionHandler(kServerError, nil, nil);
           return;
       }
       else {
           error = [NSError errorWithMessage:[NSString stringWithFormat:@"request failure: %ld", response.statusCode]
                                fromFunction:__FUNCTION__];
           completionHandler(kInvalid, nil, error);
           return;
       }
   }];
}

+ (void)parseGetPurchasePricesResponse:(NSData*_Nonnull)jsonData
                        purchasePrices:(NSArray**_Nonnull)purchasePrices
                             withError:(NSError**_Nullable)error
{
    *error = nil;
    *purchasePrices = nil;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization error" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSArray class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSArray *data = object;

    NSMutableArray *result = [[NSMutableArray alloc] init];

    for (id item in data) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            *error = [NSError errorWithMessage:@"Invalid JSON substructure" fromFunction:__FUNCTION__];
            return;
        }

        NSDictionary *itemDict = item;

        PsiCashPurchasePrice *purchasePrice = [[PsiCashPurchasePrice alloc] init];

        // Note: isKindOfClass is false if the key isn't found

        if (![itemDict[@"Price"] isKindOfClass:NSNumber.class]) {
            *error = [NSError errorWithMessage:@"Price is not a number" fromFunction:__FUNCTION__];
            return;
        }
        purchasePrice.price = itemDict[@"Price"];

        if (![itemDict[@"Class"]  isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"Class is not a string" fromFunction:__FUNCTION__];
            return;
        }
        else if ([(NSString*)itemDict[@"Class"] length] == 0) {
            *error = [NSError errorWithMessage:@"Class string is empty" fromFunction:__FUNCTION__];
            return;
        }
        purchasePrice.transactionClass = itemDict[@"Class"];

        if (![itemDict[@"Distinguisher"]  isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"Distinguisher is not a string" fromFunction:__FUNCTION__];
            return;
        }
        else if ([(NSString*)itemDict[@"Distinguisher"] length] == 0) {
            *error = [NSError errorWithMessage:@"Distinguisher string is empty" fromFunction:__FUNCTION__];
            return;
        }
        purchasePrice.distinguisher = itemDict[@"Distinguisher"];

        [result addObject:purchasePrice];
    }

    *purchasePrices = result;
}

#pragma mark - NewTracker

/*!
 Possible status codes:

    • kSuccess

    • kServerError

 */
- (void)newTracker:(void (^)(PsiCashRequestStatus status,
                             NSDictionary* authTokens,
                             NSError *error))completionHandler
{
    NSMutableURLRequest *request = [PsiCash createRequestFor:@"/new-tracker"
                                                  withMethod:@"POST"
                                              withQueryItems:nil
                                              withAuthTokens:nil];

    [self doRequestWithRetry:request
                    useCache:NO
             numberOfRetries:REQUEST_RETRY_LIMIT
           completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {

        if (error) {
            error = [NSError errorWrapping:error withMessage:@"request error" fromFunction:__FUNCTION__];
            completionHandler(kInvalid, nil, error);
            return;
        }

        if (response.statusCode == kHTTPStatusOK) {
            if (!data) {
                error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                completionHandler(kInvalid, nil, error);
                return;
            }

            NSDictionary* authTokens;
            [PsiCash parseNewTrackerResponse:data authTokens:&authTokens withError:&error];
            if (error != nil) {
                error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                completionHandler(kInvalid, nil, error);
                return;
            }

            [self->userID setAuthTokens:authTokens isAccount:NO];

            completionHandler(kSuccess, authTokens, nil);
            return;
        }
        else if (response.statusCode == kHTTPStatusInternalServerError) {
            completionHandler(kServerError, nil, nil);
            return;
        }
        else {
            error = [NSError errorWithMessage:[NSString stringWithFormat:@"request failure: %ld", response.statusCode]
                                 fromFunction:__FUNCTION__];
            completionHandler(kInvalid, nil, error);
            return;
        }
    }];
}

+ (void)parseNewTrackerResponse:(NSData*)jsonData authTokens:(NSDictionary**)authTokens withError:(NSError**)error
{
    *error = nil;
    *authTokens = 0;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization error" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    // Sanity check that there are at least three tokens present

    int tokensFound = 0;
    for (id key in data) {
        id value = [data objectForKey:key];

        // Note: isKindOfClass is false if the value is nil
        if (![value isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"token is not a string" fromFunction:__FUNCTION__];
            return;
        }
        else if ([(NSString*)value length] == 0) {
            *error = [NSError errorWithMessage:@"token string is empty" fromFunction:__FUNCTION__];
            return;
        }

        tokensFound += 1;
    }

    if (tokensFound < 3) {
        *error = [NSError errorWithMessage:@"not enough tokens received" fromFunction:__FUNCTION__];
        return;
    }

    *authTokens = data;
}

#pragma mark - ValidateTokens

/*!
 Possible status codes:

    • kSuccess

    • kServerError
 */
- (void)validateTokens:(void (^)(PsiCashRequestStatus status,
                                 BOOL isAccount,
                                 NSDictionary* tokensValid,
                                 NSError *error))completionHandler
{
    NSMutableURLRequest *request = [PsiCash createRequestFor:@"/validate-tokens"
                                                  withMethod:@"GET"
                                              withQueryItems:nil
                                              withAuthTokens:self->userID.authTokens];

    [self doRequestWithRetry:request
                    useCache:NO
             numberOfRetries:REQUEST_RETRY_LIMIT
           completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {

       if (error) {
           error = [NSError errorWrapping:error withMessage:@"request error" fromFunction:__FUNCTION__];
           completionHandler(kInvalid, NO, nil, error);
           return;
       }

       if (response.statusCode == kHTTPStatusOK) {
           if (!data) {
               error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
               completionHandler(kInvalid, NO, nil, error);
               return;
           }

           BOOL isAccount;
           NSDictionary* tokensValid;
           [PsiCash parseValidateTokensResponse:data
                                      isAccount:&isAccount
                                    tokensValid:&tokensValid
                                      withError:&error];
           if (error != nil) {
               error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
               completionHandler(kInvalid, NO, nil, error);
               return;
           }

           self->userID.isAccount = isAccount;

           completionHandler(kSuccess, isAccount, tokensValid, nil);
           return;
       }
       else if (response.statusCode == kHTTPStatusInternalServerError) {
           completionHandler(kServerError, NO, nil, nil);
           return;
       }
       // We're not checking for a 400 error, since we're not going to give bad input.
       else {
           error = [NSError errorWithMessage:[NSString stringWithFormat:@"request failure: %ld", response.statusCode]
                                fromFunction:__FUNCTION__];
           completionHandler(kInvalid, NO, nil, error);
           return;
       }
    }];
}

+ (void)parseValidateTokensResponse:(NSData*)jsonData isAccount:(BOOL*)isAccount tokensValid:(NSDictionary**)tokensValid withError:(NSError**)error
{
    *error = nil;
    *isAccount = NO;
    *tokensValid = 0;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization error" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    if (![data[@"IsAccount"] isKindOfClass:NSNumber.class]) {
        *error = [NSError errorWithMessage:@"IsAccount is not a number" fromFunction:__FUNCTION__];
        return;
    }
    *isAccount = [(NSNumber*)data[@"IsAccount"] boolValue];

    if (![data[@"TokensValid"] isKindOfClass:NSDictionary.class]) {
        *error = [NSError errorWithMessage:@"TokensValid is not a dictionary" fromFunction:__FUNCTION__];
        return;
    }
    *tokensValid = data[@"TokensValid"];
}

#pragma mark - ValidateOrAcquireTokens

- (void)validateOrAcquireTokens:(void (^_Nonnull)(PsiCashRequestStatus status,
                                                  NSArray*_Nullable validTokenTypes,
                                                  BOOL isAccount,
                                                  NSError*_Nullable error))completionHandler
{
    NSDictionary *authTokens = self->userID.authTokens;
    if (!authTokens || [authTokens count] == 0) {
        // No tokens. Get new Tracker tokens.
        [self newTracker:^(PsiCashRequestStatus status,
                           NSDictionary *authTokens,
                           NSError *error) {
            if (error) {
                error = [NSError errorWrapping:error withMessage:@"newTracker request error" fromFunction:__FUNCTION__];
                completionHandler(kInvalid, nil, NO, error);
                return;
            }

            if (status != kSuccess) {
                completionHandler(status, nil, NO, nil);
                return;
            }

            // newTracker calls [self->userID setAuthTokens]

            completionHandler(kSuccess, [authTokens allKeys], NO, nil);
            return;
        }];
        return;
    }

    // Validate the tokens we have.
    [self validateTokens:^(PsiCashRequestStatus status,
                           BOOL isAccount,
                           NSDictionary *tokensValid,
                           NSError *error) {
        if (error) {
            error = [NSError errorWrapping:error withMessage:@"validateTokens request error" fromFunction:__FUNCTION__];
            completionHandler(kInvalid, nil, NO, error);
            return;
        }

        if (status != kSuccess) {
            completionHandler(status, nil, NO, nil);
            return;
        }

        // If none of the tokens are valid, then validateTokens won't know if they
        // belong to an account or not. In that case, we only have our previous
        // isAccount value to check.
        isAccount = self->userID.isAccount || isAccount;

        NSDictionary* onlyValidTokens = [PsiCash onlyValidTokens:self->userID.authTokens tokensValid:tokensValid];

        [self->userID setAuthTokens:onlyValidTokens isAccount:isAccount];

        // If the tokens are for an account, then there's nothing more to do
        // (unlike for a Tracker, we can't just get new ones).
        if (isAccount) {
            completionHandler(kSuccess, [onlyValidTokens allKeys], true, nil);
            return;
        }

        // If the tokens are for a Tracker, then if they're all expired we should
        // get new ones. (They should all expire at the same time.)
        if ([onlyValidTokens count] == 0) {
            [self newTracker:^(PsiCashRequestStatus status,
                               NSDictionary *authTokens,
                               NSError *error) {
                if (error) {
                    error = [NSError errorWrapping:error withMessage:@"newTracker request error" fromFunction:__FUNCTION__];
                    completionHandler(kInvalid, nil, NO, error);
                    return;
                }

                if (status != kSuccess) {
                    completionHandler(status, nil, NO, nil);
                    return;
                }

                // newTracker calls [self->userID setAuthTokens]

                completionHandler(kSuccess, [authTokens allKeys], NO, nil);
                return;
            }];
            return;
        }

        // Otherwise we have valid Tracker tokens.
        completionHandler(kSuccess, [onlyValidTokens allKeys], NO, nil);
        return;
    }];
}

#pragma mark - helpers

+ (NSMutableURLRequest*)createRequestFor:(NSString*_Nonnull)path
                              withMethod:(NSString*_Nonnull)method
                          withQueryItems:(NSArray*_Nullable)queryItems
                          withAuthTokens:(NSDictionary*_Nullable)authTokens
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [request setTimeoutInterval:TIMEOUT_SECS];

    [request setHTTPMethod:method];

    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.scheme = PSICASH_SERVER_SCHEME;
    urlComponents.host = PSICASH_SERVER_HOSTNAME;
    urlComponents.port = [[NSNumber alloc] initWithInt:PSICASH_SERVER_PORT];
    urlComponents.path = path;
    urlComponents.queryItems = queryItems;

    [request setURL:urlComponents.URL];

    if (authTokens != nil)
    {
        [request setValue:[PsiCash authTokensToHeader:authTokens] forHTTPHeaderField:AUTH_HEADER];
    }

    return request;
}

// If error is non-nil, data and response will be nil.
- (void)doRequestWithRetry:(NSURLRequest*)request
                  useCache:(BOOL)useCache
           numberOfRetries:(NSUInteger)numRetries // Set to REQUEST_RETRY_LIMIT on first call
         completionHandler:(void (^)(NSData *data, NSHTTPURLResponse *response, NSError *error))completionHandler
{
    __weak typeof (self) weakSelf = self;

    __block NSInteger remainingRetries = numRetries;

    NSURLSessionConfiguration* config = NSURLSessionConfiguration.defaultSessionConfiguration.copy;
    config.timeoutIntervalForRequest = TIMEOUT_SECS;

    if (!useCache) {
        config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    }

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            // Don't retry in the case of an actual error.
            completionHandler(nil, nil, error);
            return;
        }

        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        NSUInteger responseStatusCode = [httpResponse statusCode];

        if (responseStatusCode >= 500 && remainingRetries > 0) {
            // Server is having trouble. Retry.

            remainingRetries -= 1;

            // Back off per attempt.
            dispatch_time_t retryTime = dispatch_time(DISPATCH_TIME_NOW, (REQUEST_RETRY_LIMIT-remainingRetries) * NSEC_PER_SEC);

            NSLog(@"doRequestWithRetry: Waiting for retry; remainingRetries:%lu", (unsigned long)remainingRetries); // DEBUG

            dispatch_after(retryTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
                NSLog(@"doRequestWithRetry: Retrying"); // DEBUG

                // Recursive retry.
                [weakSelf doRequestWithRetry:request
                                    useCache:useCache
                             numberOfRetries:remainingRetries
                           completionHandler:completionHandler];
            });
            return;
        }
        else {
            // Success or no more retries available.
            completionHandler(data, httpResponse, nil);
            return;
        }
    }];

    [dataTask resume];
}

+ (NSDictionary*)onlyValidTokens:(NSDictionary*)authTokens tokensValid:(NSDictionary*)tokensValid
{
    NSMutableDictionary* onlyValidTokens = [[NSMutableDictionary alloc] init];

    for (id tokenType in authTokens) {
        NSString *token = [authTokens objectForKey:tokenType];
        NSNumber *valid = [tokensValid objectForKey:token];

        if ([valid boolValue]) {
            onlyValidTokens[tokenType] = token;
        }
    }

    return onlyValidTokens;
}

+ (id)authTokensToHeader:(NSDictionary*)authTokens
{
    NSMutableString *authTokensString = [NSMutableString string];

    for (id key in authTokens) {
        id token = [authTokens objectForKey:key];

        if ([authTokensString length] > 0) {
            [authTokensString appendString:@","];
        }

        [authTokensString appendString:(NSString*)token];
    }

    return authTokensString;
}

@end

/*
 If we decide to add proxy support -- for using this in Psiphon Browser, say -- it
 can be done with this code (adapted from TunneledWebRequest):

 NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration.copy;
 config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;

 NSMutableDictionary* connectionProxyDictionary = [[NSMutableDictionary alloc] init];
 connectionProxyDictionary[(NSString*)kCFStreamPropertySOCKSProxy] = [NSNumber numberWithInt:1];
 connectionProxyDictionary[(NSString*)kCFStreamPropertySOCKSProxyHost] = @"127.0.0.1";
 connectionProxyDictionary[(NSString*)kCFStreamPropertySOCKSProxyPort] = [NSNumber numberWithInt:1234]; // SOCKS port
 connectionProxyDictionary[(NSString*)kCFNetworkProxiesHTTPEnable] = [NSNumber numberWithInt:1];
 connectionProxyDictionary[(NSString*)kCFNetworkProxiesHTTPProxy] = @"127.0.0.1";
 connectionProxyDictionary[(NSString*)kCFNetworkProxiesHTTPPort] = [NSNumber numberWithInt:1234]; // HTTP port
 connectionProxyDictionary[(NSString*)kCFStreamPropertyHTTPSProxyHost] = @"127.0.0.1";
 connectionProxyDictionary[(NSString*)kCFStreamPropertyHTTPSProxyPort] = [NSNumber numberWithInt:1234]; // HTTP port
 config.connectionProxyDictionary = connectionProxyDictionary;

 NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
 */
