

#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_MACCATALYST

#import <UIKit/UIKit.h>

#import "OIDExternalUserAgent.h"

@class SFSafariViewController;

NS_ASSUME_NONNULL_BEGIN

/*! @brief An iOS specific external user-agent that uses the best possible user-agent available
        depending on the version of iOS to present the request.
 */
API_UNAVAILABLE(macCatalyst)
@interface OIDSAUserAgentIOS : NSObject<OIDExternalUserAgent>

- (nullable instancetype)init API_AVAILABLE(ios(11))
    __deprecated_msg("This method will not work on iOS 13, use "
                     "initWithPresentingViewController:presentingViewController");

/*! @brief The designated initializer.
    @param presentingViewController The view controller from which to present the authentication UI.
    @discussion The specific authentication UI used depends on the iOS version and accessibility
        options. iOS 8 uses the system browser, iOS 9-10 use @c SFSafariViewController, iOS 11 uses
        @c SFAuthenticationSession
        (unless Guided Access is on which does not work) or uses @c SFSafariViewController, and iOS
        12+ uses @c ASWebAuthenticationSession (unless Guided Access is on).
 */
- (nullable instancetype)initWithPresentingViewController:
    (UIViewController *)presentingViewController
    NS_DESIGNATED_INITIALIZER;

/*! @brief Create an external user-agent which optionally uses a private authentication session.
    @param presentingViewController The view controller from which to present the browser.
    @param prefersEphemeralSession Whether the caller prefers to use a private authentication
        session. See @c ASWebAuthenticationSession.prefersEphemeralWebBrowserSession for more.
    @discussion Authentication is performed with @c ASWebAuthenticationSession (unless Guided Access
        is on), setting the ephemerality based on the argument.
 */
- (nullable instancetype)initWithPresentingViewController:
    (UIViewController *)presentingViewController
                                  prefersEphemeralSession:(BOOL)prefersEphemeralSession
    API_AVAILABLE(ios(13));

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS || TARGET_OS_MACCATALYST
