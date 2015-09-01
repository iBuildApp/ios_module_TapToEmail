/****************************************************************************
 *                                                                           *
 *  Copyright (C) 2014-2015 iBuildApp, Inc. ( http://ibuildapp.com )         *
 *                                                                           *
 *  This file is part of iBuildApp.                                          *
 *                                                                           *
 *  This Source Code Form is subject to the terms of the iBuildApp License.  *
 *  You can obtain one at http://ibuildapp.com/license/                      *
 *                                                                           *
 ****************************************************************************/

#import "mEmail.h"
#import "TBXML.h"
#import "notifications.h"

@interface TPortraitMailVC : MFMailComposeViewController
@end

#pragma mark - TPortraitMailVC

@implementation TPortraitMailVC


#pragma mark - Interface orientation handling

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return UIInterfaceOrientationIsPortrait(interfaceOrientation); // YES
}

#pragma mark IOS6 support for interface orientation
- (BOOL)shouldAutorotate
{
  return YES;
}
- (NSUInteger)supportedInterfaceOrientations
{
  return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
  return UIInterfaceOrientationPortrait;
}


@end

#pragma mark - mEmailViewController

/**
 *  ViewController for widget TapToEmail
 */
@interface mEmailViewController()

/**
 *  Array of addressees
 */
@property (nonatomic, strong) NSArray          *szMailtoList;

/**
 *  Email subject
 */
@property (nonatomic, copy  ) NSString         *szSubject;

/**
 *  Message text
 */
@property (nonatomic, copy  ) NSString         *szMessage;

/**
 *  ViewController title
 */
@property (nonatomic, copy  ) NSString         *szTitle;

/**
 *  Mail ViewController
 */
@property (nonatomic, strong) UIViewController *mailViewController;

/**
 *  Add link to ibuildapp.com to sharing messages
 */
@property (nonatomic, strong) NSArray          *objContainer;

@property (nonatomic, assign) BOOL              bShowLink;      // YES, if we need to add text "send from iBuildApp" to message
@end

@implementation mEmailViewController
@synthesize szMailtoList,
szSubject,
szMessage,
szTitle,
mailViewController,
parentViewController,
objContainer,
bShowLink;

#pragma mark -
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if ( self )
  {
    self.szMailtoList = nil;
    self.szSubject    = nil;
    self.szMessage    = nil;
    self.szTitle      = nil;
    self.mailViewController = nil;
    self.objContainer       = nil;
    self.bShowLink    = NO;
  }
  return self;
}

- (void)dealloc
{
  self.szMailtoList = nil;
  self.szSubject    = nil;
  self.szMessage    = nil;
  self.szTitle      = nil;
  if ( self.mailViewController )
    [self.mailViewController dismissModalViewControllerAnimated:YES];
  self.mailViewController = nil;
  self.objContainer       = nil;
  [super dealloc];
}

#pragma mark - 

/**
 *  Special parser for processing original xml file
 *
 *  @param xmlElement_ XML node
 *  @param params_     Dictionary with module parameters
 */
+ (void)parseXML:(NSValue *)xmlElement_
     withParams:(NSMutableDictionary *)params_
{
  TBXMLElement element;
  [xmlElement_ getValue:&element];

  NSMutableArray *contentArray = [NSMutableArray array];
  
  NSString *szTitle = @"";
  TBXMLElement *titleElement = [TBXML childElementNamed:@"title" parentElement:&element];
  if ( titleElement )
    szTitle = [TBXML textForElement:titleElement];
  
     // 1. adding a zero element to array
  [contentArray addObject:[NSDictionary dictionaryWithObject:szTitle ? szTitle : @"" forKey:@"title" ] ];
  
    /// 2. search for tag <mailto>
  NSMutableDictionary *mailParams = [NSMutableDictionary dictionary];
  NSMutableArray      *mailToList = [NSMutableArray array];
  
  TBXMLElement *mailtoElement = [TBXML childElementNamed:@"mailto" parentElement:&element];
  while( mailtoElement )
  {
    NSString *szMailTo = [TBXML textForElement:mailtoElement];
    if ( [szMailTo length] )
      [mailToList addObject:szMailTo];
    mailtoElement = [TBXML nextSiblingNamed:@"mailto" searchFromElement:mailtoElement];
  }
  if ( [mailToList count] )
    [mailParams setObject:mailToList forKey:@"mailto"];
  
  
    /// 3. search for tag <subject>
  TBXMLElement *subjectElement = [TBXML childElementNamed:@"subject" parentElement:&element];
  if ( subjectElement )
  {
    NSString *szSubject = [TBXML textForElement:subjectElement];
    if ( [szSubject length] )
      [mailParams setObject:szSubject forKey:@"subject"];
  }
  
    /// 4. search for tag <message>
  TBXMLElement *messageElement = [TBXML childElementNamed:@"message" parentElement:&element];
  if ( messageElement )
  {
    NSString *szMessage = [TBXML textForElement:messageElement];
    if ( [szMessage length] )
      [mailParams setObject:szMessage forKey:@"message"];
  }
  if ( [mailParams count] )
    [contentArray addObject:mailParams];
  
  [params_ setObject:contentArray forKey:@"data"];
}


- (void)setParams:(NSMutableDictionary *)params
{
  if ( !params )
    return;
  
  NSArray *mailParams = [params objectForKey:@"data"];
  
  if ( [mailParams count] < 2 )
    return;
  
  self.szTitle = [[mailParams objectAtIndex:0] objectForKey:@"title"];
  
  
    // other params must be in second element of array
  NSDictionary *mailParamsDictionary = [mailParams objectAtIndex:1];
  self.bShowLink    = [[params objectForKey:@"showLink"] isEqual:@"1"];
  self.szMailtoList = [mailParamsDictionary objectForKey:@"mailto"];
  self.szSubject    = [mailParamsDictionary objectForKey:@"subject"];
  if ( !self.szSubject )
    self.szSubject = @"";
  self.szMessage    = [mailParamsDictionary objectForKey:@"message"];
  if ( !self.szMessage )
    self.szMessage = @"";
}

/**
 *  Crutch for supporting scenarios.
 *  This does not necessarily call module (i.e. adding viewController to stack may not happen).
 *  For example, if there is a call third-party application, the method returns a pointer to an object of type NSObject.
 *  Otherwise - the caller makes adding view controller in the stack.
 *
 *  @return id
 */
- (id)performActionWithViewController:(UIViewController *)viewController_
{
  BOOL isHtml = NO;
    // supplement content of the letter with links to iBuildApp, if self.bShowLink == YES
  if (self.bShowLink)
  {
    self.szMessage = [self.szMessage stringByAppendingString:[NSString stringWithFormat:@"<br /><br />(%@ <a href=\"http://ibuildapp.com\">iBuildApp</a>)", NSLocalizedString(@"mEM_sentFrom", @"Sent from")]];
    isHtml = YES;
  }
  if (self.bShowLink)
    self.szSubject = [self.szSubject stringByAppendingString:[NSString stringWithFormat:@" (%@ iBuildApp)", NSLocalizedString(@"mEM_sentFrom", @"Sent from")]];

  
  if ( ![MFMailComposeViewController canSendMail] )
  {
    /**
     *  at the moment we can not send email, because likely not available active account.
     Send user to the mailer.
     */
    NSMutableString  *mailto = [NSMutableString stringWithString:@"mailto:"];
    
    [mailto appendString:@"?cc="];
    for( NSString *rcp in self.szMailtoList )
    {
      [mailto appendString:rcp];
      [mailto appendString:@","];
    }
    if ( [self.szSubject length] )
    {
      [mailto appendString:@"&subject="];
      [mailto appendString:self.szSubject];
    }
    if ( [self.szMessage length] )
    {
      [mailto appendString:@"&body="];
      [mailto appendString:self.szMessage];
    }
    NSString *email = [mailto stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:email]];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"core_cannotSendEmailAlertTitle", @"Mail cannot be send")
                                                    message:NSLocalizedString(@"core_cannotSendEmailAlertMessage", @"This device not configured to send mail")
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"core_cannotSendEmailAlertOkButtonTitle", @"OK")
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
    
      // unable to run the module...
    return nil;
  }
  else
  {
      // choose an appropriate representation for:
      // - iPad  : - supporting all screen orientations
      // - iPhone: - supporting only portrait orientation
    MFMailComposeViewController *mailComposer = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone ?
    [[[TPortraitMailVC alloc] init] autorelease] :
    [[[ MFMailComposeViewController alloc] init] autorelease];
    if ( !mailComposer )
      return nil;
    
    mailComposer.mailComposeDelegate = self;
    [[mailComposer navigationBar] setTintColor:[UIColor blackColor]];
    [mailComposer setTitle:self.szTitle];
    
    [mailComposer setToRecipients:self.szMailtoList];
    [mailComposer setSubject:self.szSubject];
    
    [mailComposer setMessageBody:self.szMessage
                          isHTML:isHtml];
    [mailComposer.view setAutoresizingMask: UIViewAutoresizingFlexibleWidth |
     UIViewAutoresizingFlexibleHeight ];
    [mailComposer.view setAutoresizesSubviews:YES];
    
    if ( [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad )
      mailComposer.modalPresentationStyle = UIModalPresentationFormSheet;
    
    self.mailViewController   = mailComposer;
    [viewController_ presentModalViewController:mailComposer
                                       animated:YES];
    
      /// set title for mailViewComposer with dirty hack:
    [[[[mailComposer viewControllers] lastObject] navigationItem] setTitle:self.szTitle];
    
      // We must return an object with type NOT ViewController!
      // otherwise it will be added to the stack of viewControllers, this will cause a crash!
    
      //  So we must hold self to NSArray and return it
    self.objContainer = [NSArray arrayWithObject:self];
    return self.objContainer;
  }
  return nil;
}

#pragma mark - Mail
- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error
{
	switch (result)
	{
		case MFMailComposeResultCancelled:
			break;
		case MFMailComposeResultSaved:
			break;
		case MFMailComposeResultSent:
		{
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                      message:NSLocalizedString(@"mEM_sendingSuccessMessage", @"Thank You - your information has been sent")
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"mEM_sendingSuccessOkButton", @"OK")
                                            otherButtonTitles:nil];
      [alert show];
      [alert release];
		}
      break;
		case MFMailComposeResultFailed:
		default:
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"mEM_sendingErrorTitle", @"Email")
                                                      message:NSLocalizedString(@"mEM_sendingErrorMessage", @"Sending Failed - Unknown Error")
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"mEM_sendingSErrorOkButton", @"OK")
                                            otherButtonTitles:nil];
			[alert show];
			[alert release];
		}
			
			break;
	}
  
	[self.mailViewController dismissModalViewControllerAnimated:YES];
  
    // send notification: objContainer can be dispossed
  [[NSNotificationCenter defaultCenter] postNotificationName:kAPP_NOTIFICATION_RELEASE_OBJECT
                                                      object:self.objContainer];
  self.mailViewController = nil;
  self.objContainer = nil;
}

@end
