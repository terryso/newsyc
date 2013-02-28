//
//  BrowserController.m
//  newsyc
//
//  Created by Grant Paul on 3/7/11.
//  Copyright 2011 Xuzz Productions, LLC. All rights reserved.
//

#import <ShareSDK/ShareSDK.h>
#import <AGCommon/UIDevice+Common.h>
#import "BrowserController.h"

#import "NSArray+Strings.h"
#import "UIColor+Orange.h"
#import "UIApplication+ActivityIndicator.h"
#import "UINavigationItem+MultipleItems.h"
#import "SharingController.h"

@implementation BrowserController
@synthesize currentURL;

- (id)initWithURL:(NSURL *)url {
    if ((self = [super init])) {
        rootURL = url;
        [self setCurrentURL:url];
        [self setHidesBottomBarWhenPushed:YES];
    }

    return self;
}

- (void)retainNetworkIndicator {
    [[UIApplication sharedApplication] retainNetworkActivityIndicator];
    networkRetainCount += 1;
}

- (void)releaseNetworkIndicator {
    [[UIApplication sharedApplication] releaseNetworkActivityIndicator];
    networkRetainCount -= 1;
}

- (void)releaseNetworkIndicatorCompletely {
    // there may be multiple connections open on the webview, so we have
    // to keep track of how many are open ourselves and release the indicator
    // that many times to make sure it is properly hidden when we are popped
    for (NSInteger i = 0; i < networkRetainCount; i++) {
        [[UIApplication sharedApplication] releaseNetworkActivityIndicator];
    }
}

- (void)dealloc {
    [webview setDelegate:nil];
    [self releaseNetworkIndicatorCompletely];

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [webview release];
    [toolbar release];
    [toolbarItem release];
    [backItem release];
    [forwardItem release];
    [shareItem release];
    [refreshItem release];
    [loadingItem release];
    [spacerItem release];

    [super dealloc];
}

- (void)updateToolbarItems {
    [backItem setEnabled:[webview canGoBack]];
    [forwardItem setEnabled:[webview canGoForward]];

    BarButtonItem *changableItem = nil;
    if ([webview isLoading])
        changableItem = loadingItem;
    else
        changableItem = refreshItem;

    [toolbar setItems:[NSArray arrayWithObjects:spacerItem, backItem, spacerItem, spacerItem, forwardItem, spacerItem, spacerItem, spacerItem, readabilityItem, spacerItem, spacerItem, changableItem, spacerItem, spacerItem, shareItem, spacerItem, nil]];
}

- (void)loadView {
    [super loadView];

    toolbar = [[UIToolbar alloc] init];
    [toolbar sizeToFit];

    backItem = [[BarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    forwardItem = [[BarButtonItem alloc] initWithImage:[UIImage imageNamed:@"forward.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    readabilityItem = [[BarButtonItem alloc] initWithImage:[UIImage imageNamed:@"readability.png"] style:UIBarButtonItemStylePlain target:self action:@selector(readability)];
    refreshItem = [[BarButtonItem alloc] initWithImage:[UIImage imageNamed:@"refresh.png"] style:UIBarButtonItemStylePlain target:self action:@selector(reload)];
    shareItem = [[BarButtonItem alloc] initWithImage:[UIImage imageNamed:@"action.png"] style:UIBarButtonItemStylePlain target:self action:@selector(share:)];
    spacerItem = [[BarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    loadingItem = [[ActivityIndicatorItem alloc] initWithSize:[[refreshItem image] size]];
    [self updateToolbarItems];

    webview = [[UIWebView alloc] initWithFrame:[[self view] bounds]];
    [webview setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [webview setDelegate:self];
    [webview setScalesPageToFit:YES];
    [[self view] addSubview:webview];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (![webview request]) {
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:rootURL];
        [webview loadRequest:[request autorelease]];
    }

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"disable-orange"]) {
        [toolbar setTintColor:[UIColor mainOrangeColor]];
    } else {
        [toolbar setTintColor:nil];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        CGRect toolbarFrame = [toolbar bounds];
        toolbarFrame.origin.y = [[self view] bounds].size.height - toolbarFrame.size.height;
        toolbarFrame.size.width = [[self view] bounds].size.width;
        [toolbar setFrame:toolbarFrame];
        [toolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
        [[self view] addSubview:toolbar];

        CGRect webviewFrame = [[self view] bounds];
        webviewFrame.size.height -= toolbarFrame.size.height;
        [webview setFrame:webviewFrame];
    } else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        CGRect toolbarFrame = [toolbar bounds];
        toolbarFrame.size.width = 280.0f;
        [toolbar setFrame:toolbarFrame];

        [toolbar setBackgroundImage:[UIImage imageNamed:@"clear.png"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
        toolbarItem = [[BarButtonItem alloc] initWithCustomView:toolbar];
        [[self navigationItem] addRightBarButtonItem:toolbarItem atPosition:UINavigationItemPositionLeft];
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];

    [webview setDelegate:nil];
    [self releaseNetworkIndicatorCompletely];

    [[self navigationItem] removeRightBarButtonItem:toolbarItem];

    [webview release];
    webview = nil;
    [toolbar release];
    toolbar = nil;
    [toolbarItem release];
    toolbarItem = nil;
    [backItem release];
    backItem = nil;
    [forwardItem release];
    forwardItem = nil;
    [readabilityItem release];
    readabilityItem = nil;
    [refreshItem release];
    refreshItem = nil;
    [shareItem release];
    shareItem = nil;
    [loadingItem release];
    loadingItem = nil;
    [spacerItem release];
    spacerItem = nil;
}

- (void)readability {
    [webview stringByEvaluatingJavaScriptFromString:kReadabilityBookmarkletCode];
}

- (NSString *)pageTitle {
    return [webview stringByEvaluatingJavaScriptFromString:@"document.title"];
}

- (void)reload {
    [webview reload];
}

- (void)stop {
    [webview stopLoading];
}

- (void)goBack {
    [webview goBack];
}

- (void)goForward {
    [webview goForward];
}

- (void)share:(BarButtonItem *)sender {
    if ([UIDevice currentDevice].isPad) {
        SharingController *sharingController = [[SharingController alloc] initWithURL:currentURL title:[self pageTitle] fromController:self];
        [sharingController showFromBarButtonItem:shareItem];
        [sharingController release];
        /*id<ISSPublishContent> publishContent = [ShareSDK publishContent:content
                                                          defaultContent:@""
                                                                   image:nil
                                                            imageQuality:0.8
                                                               mediaType:SSPublishContentMediaTypeNews
                                                                   title:@"ShareSDK"
                                                                     url:@"http://www.sharesdk.cn"
                                                            musicFileUrl:nil
                                                                 extInfo:nil
                                                                fileData:nil];

         [ShareSDK showShareActionSheet:self
                          iPadContainer:[ShareSDK iPadShareContainerWithView:toolbar arrowDirect:UIPopoverArrowDirectionUp]
                              shareList:nil
                                content:publishContent
                          statusBarTips:YES
                             convertUrl:YES      //委托转换链接标识，YES：对分享链接进行转换，NO：对分享链接不进行转换，为此值时不进行回流统计。
                            authOptions:nil
                       shareViewOptions:[ShareSDK defaultShareViewOptionsWithTitle:@"内容分享"
                                                                   oneKeyShareList:[NSArray defaultOneKeyShareList]
                                                                    qqButtonHidden:NO
                                                             wxSessionButtonHidden:NO
                                                            wxTimelineButtonHidden:NO
                                                              showKeyboardOnAppear:YES]
                                 result:^(ShareType type, SSPublishContentState state, id<ISSStatusInfo> statusInfo, id<ICMErrorInfo> error, BOOL end) {
                                     if (state == SSPublishContentStateSuccess)
                                     {
                                         NSLog(@"分享成功");
                                     }
                                     else if (state == SSPublishContentStateFail)
                                     {
                                         NSLog(@"分享失败,错误码:%d,错误描述:%@", [error errorCode], [error errorDescription]);
                                     }
                                 }];*/
    } else {
        NSString *content = [NSString stringWithFormat:@"%@ %@", [self pageTitle], currentURL];
        id<ISSPublishContent> publishContent = [ShareSDK publishContent:content
                                                         defaultContent:@""
                                                                  image:nil
                                                           imageQuality:0.8
                                                              mediaType:SSPublishContentMediaTypeNews
                                                                  title:@"ShareSDK"
                                                                    url:@"http://nickyao.cnblogs.com"
                                                           musicFileUrl:nil
                                                                extInfo:nil
                                                               fileData:nil];

        [ShareSDK shareContentWithType:ShareTypeAny
                               content:publishContent
                   containerController:self
                         statusBarTips:YES
                       oneKeyShareList:[NSArray defaultOneKeyShareList]
                        shareViewStyle:ShareViewStyleDefault
                        shareViewTitle:@"内容分享"
                                result:nil];
    }

}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self updateToolbarItems];

    [self releaseNetworkIndicator];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self updateToolbarItems];
    [self setCurrentURL:[[webView request] URL]];
    [[self navigationItem] setTitle:[self pageTitle]];

    [self releaseNetworkIndicator];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self retainNetworkIndicator];

    [self updateToolbarItems];
}

// These 3 methods from Apple tech doc: http://developer.apple.com/library/ios/#qa/qa1629/_index.html
- (void)openExternalURL:(NSURL *)external {
    externalURL = [external retain];

    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:external] delegate:self startImmediately:YES];
    [conn release];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (response)
        externalURL = [[response URL] retain];
    return request;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Opening Link" message:@"Are you sure you want to leave news:yc to open this link?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Open Link", nil];
    [alert show];
    [alert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [[UIApplication sharedApplication] openURL:externalURL];
    }

    [externalURL release];
    externalURL = nil;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [alertView release];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    [self updateToolbarItems];

    NSArray *hosts = [NSArray arrayWithObjects:@"itunes.apple.com", @"phobos.apple.com", @"youtube.com", @"maps.google.com", nil];
    NSURL *url = [request URL];
    if (navigationType == UIWebViewNavigationTypeLinkClicked && [hosts containsString:[url host]]) {
        [self openExternalURL:url];
        return NO;
    }

    if (navigationType == UIWebViewNavigationTypeLinkClicked ||
            navigationType == UIWebViewNavigationTypeFormSubmitted ||
            navigationType == UIWebViewNavigationTypeFormResubmitted) {
        [self setCurrentURL:[request URL]];
    }

    return YES;
}

AUTOROTATION_FOR_PAD_ONLY

@end
