/*! @file OIDExternalUserAgentIOS.m
    @brief AppAuth iOS SDK
    @copyright
        Copyright 2016 Google Inc. All Rights Reserved.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_MACCATALYST

#import "OIDSAUserAgentIOS.h"

#import <SafariServices/SafariServices.h>
#import <AuthenticationServices/AuthenticationServices.h>

#import "OIDErrorUtilities.h"
#import "OIDExternalUserAgentSession.h"
#import "OIDExternalUserAgentRequest.h"
#import "OIDAuthorizationRequest.h"

#if !TARGET_OS_MACCATALYST

NS_ASSUME_NONNULL_BEGIN

@interface OIDSAUserAgentIOS ()<NSURLSessionTaskDelegate>
@end

@implementation OIDSAUserAgentIOS {
  UIViewController *_presentingViewController;
  BOOL _prefersEphemeralSession;

  BOOL _externalUserAgentFlowInProgress;
  __weak id<OIDExternalUserAgentSession> _session;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  __weak SFSafariViewController *_safariVC;
  SFAuthenticationSession *_authenticationVC;
  ASWebAuthenticationSession *_webAuthenticationVC;
  NSURLSession *_urlSession;
  NSURLCredential *_urlCredential;
  NSURL *_callbackURL;
#pragma clang diagnostic pop
}

- (nullable instancetype)init {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  return [self initWithPresentingViewController:nil];
#pragma clang diagnostic pop
}

- (nullable instancetype)initWithPresentingViewController:
    (UIViewController *)presentingViewController {
  self = [super init];
  if (self) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    NSAssert(presentingViewController != nil,
             @"presentingViewController cannot be nil on iOS 13");
#endif // __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    
    _presentingViewController = presentingViewController;
  }
  return self;
}

- (nullable instancetype)initWithPresentingViewController:
    (UIViewController *)presentingViewController
                                  prefersEphemeralSession:(BOOL)prefersEphemeralSession {
  self = [self initWithPresentingViewController:presentingViewController];
  if (self) {
    _prefersEphemeralSession = prefersEphemeralSession;
  }
  return self;
}

- (BOOL)presentExternalUserAgentRequest:(id<OIDExternalUserAgentRequest>)request
                                session:(id<OIDExternalUserAgentSession>)session {
  if (_externalUserAgentFlowInProgress) {
    // TODO: Handle errors as authorization is already in progress.
    return NO;
  }

  _externalUserAgentFlowInProgress = YES;
  _session = session;
  
  NSURL *requestURL = [request externalUserAgentRequestURL];
  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *urlSession = [NSURLSession sessionWithConfiguration: sessionConfiguration
                                                           delegate: self
                                                      delegateQueue: nil];
  __weak OIDSAUserAgentIOS *weakSelf = self;
  NSURLSessionDataTask *dataTask = [urlSession dataTaskWithURL: requestURL
                                             completionHandler:^(NSData * _Nullable data,
                                                                 NSURLResponse * _Nullable response,
                                                                 NSError * _Nullable error) {
    __strong OIDSAUserAgentIOS *strongSelf = weakSelf;
    if (!strongSelf) {
        return;
    }
    strongSelf->_webAuthenticationVC = nil;
    if (strongSelf->_callbackURL) {
      [strongSelf->_session resumeExternalUserAgentFlowWithURL:strongSelf->_callbackURL];
    } else {
      NSError *safariError =
          [OIDErrorUtilities errorWithCode:OIDErrorCodeUserCanceledAuthorizationFlow
                           underlyingError:error
                               description:nil];
      [strongSelf->_session failExternalUserAgentFlowWithError:safariError];
    }
  }];
  
  _urlSession = urlSession;
  [dataTask resume];

  return YES;
}

- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion {
  if (!_externalUserAgentFlowInProgress) {
    // Ignore this call if there is no authorization flow in progress.
    if (completion) completion();
    return;
  }
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  SFSafariViewController *safariVC = _safariVC;
  SFAuthenticationSession *authenticationVC = _authenticationVC;
  ASWebAuthenticationSession *webAuthenticationVC = _webAuthenticationVC;
#pragma clang diagnostic pop
  
  [self cleanUp];
  
  if (webAuthenticationVC) {
    // dismiss the ASWebAuthenticationSession
    [webAuthenticationVC cancel];
    if (completion) completion();
  } else if (authenticationVC) {
    // dismiss the SFAuthenticationSession
    [authenticationVC cancel];
    if (completion) completion();
  } else if (safariVC) {
    // dismiss the SFSafariViewController
    [safariVC dismissViewControllerAnimated:YES completion:completion];
  } else {
    if (completion) completion();
  }
}

- (void)cleanUp {
  // The weak references to |_safariVC| and |_session| are set to nil to avoid accidentally using
  // them while not in an authorization flow.
  _safariVC = nil;
  _authenticationVC = nil;
  _webAuthenticationVC = nil;
  _session = nil;
  _externalUserAgentFlowInProgress = NO;
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
  
  NSLog(@"didReceive challenge: %@", challenge.protectionSpace.authenticationMethod);
  if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate) {
    completionHandler(NSURLSessionAuthChallengeUseCredential, [OIDAuthorizationRequest credential]);
  } else {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
  }
}
    
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
  
  NSLog(@"willPerformHTTPRedirection: %@", request.debugDescription);
  completionHandler(request);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError * _Nullable)error {
    NSLog(@"didCompleteWithError: %@", error.localizedDescription);
}

@end

NS_ASSUME_NONNULL_END

#endif // !TARGET_OS_MACCATALYST

#endif // TARGET_OS_IOS || TARGET_OS_MACCATALYST
