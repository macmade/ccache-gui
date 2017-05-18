/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www-xs-labs.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

/*!
 * @file        AppInstaller.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com / www.imazing.com
 * @discussion  Adapted from "LetsMove" by PotionFactory:
 *              https://github.com/potionfactory/LetsMove
 */

#import "AppInstaller.h"

static NSString * const AlertSuppressKey = @"AppInstallerAlertSuppressKey";

NS_ASSUME_NONNULL_BEGIN

@interface AppInstaller()

+ ( BOOL )isInApplicationsFolder;
+ ( BOOL )isInDMG;
+ ( BOOL )isWriteable;
+ ( nullable NSString * )installPath;
+ ( BOOL )moveToTrash: ( NSString * )path;
+ ( void )displayError;
+ ( NSString * )appName;

@end

NS_ASSUME_NONNULL_END

@implementation AppInstaller

+ ( AppInstallerStatus )installIfNecessary
{
    NSString * installDir;
    NSString * installPath;
    
    /* Don't show again */
    if( [ [ NSUserDefaults standardUserDefaults ] boolForKey: AlertSuppressKey ] && [ AppInstaller isInDMG ] == NO )
    {
        return AppInstallerStatusNoInstallNecessary;
    }
    
    /* Already installed */
    if( [ AppInstaller isInApplicationsFolder ] )
    {
        return AppInstallerStatusNoInstallNecessary;
    }
    
    /* Don't propose to move if we cannot remove the original app (if not in a DMG) */
    if( [ AppInstaller isInDMG ] == NO && [ AppInstaller isWriteable ] == NO )
    {
        return AppInstallerStatusNoInstallNecessary;
    }
    
    /* No valid install path */
    if( ( installDir = [ AppInstaller installPath ] ) == nil )
    {
        return AppInstallerStatusInstallError;
    }
    
    /* Final location */
    installPath = [ installDir stringByAppendingPathComponent: [ [ [ NSBundle mainBundle ] bundlePath ] lastPathComponent ] ];
    
    /* Existing app */
    if( [ [ NSFileManager defaultManager ] fileExistsAtPath: installPath ] )
    {
        {
            NSRunningApplication * app;
            
            for( app in [ [ NSWorkspace sharedWorkspace ] runningApplications ] )
            {
                /* App is already running */
                if( [ app.bundleURL.path isEqualToString: installPath ] )
                {
                    {
                        NSAlert * alert;
                        
                        alert = [ NSAlert new ];
                        
                        alert.messageText     = [ NSString stringWithFormat: NSLocalizedString( @"%@ is already running", @"" ), [ AppInstaller appName ] ];
                        alert.informativeText = [ NSString stringWithFormat: NSLocalizedString( @"Another version of %@ is already running. In order to install this version, please quit the other one or restart your Mac and try again.", @"" ), [ AppInstaller appName ] ];
                        
                        [ alert addButtonWithTitle: NSLocalizedString( @"OK", @"" ) ];
                        [ alert runModal ];
                        [ NSApp terminate: nil ];
                    }
                    
                    return AppInstallerStatusInstallError;
                }
            }
        }
    }
    
    {
        NSAlert * alert;
        
        if( [ NSApp isActive ] == NO )
        {
            [ NSApp activateIgnoringOtherApps: YES ];
        }
        
        alert                        = [ NSAlert new ];
        alert.messageText            = [ NSString stringWithFormat: NSLocalizedString( @"Install %@ in your \"Applications\" Folder?", @"" ), [ AppInstaller appName ] ];
        alert.informativeText        = [ NSString stringWithFormat: NSLocalizedString( @"%@ will now be installed in your \"Applications\" folder.", @"" ), [ AppInstaller appName ] ];
        
        if( [ AppInstaller isInDMG ] == NO )
        {
            alert.showsSuppressionButton = YES;
        }
        
        [ alert addButtonWithTitle: NSLocalizedString( @"Install", @"" ) ];
        [ alert addButtonWithTitle: NSLocalizedString( @"Later", @"" ) ];
        
        /* Don't move */
        if( [ alert runModal ] != NSAlertFirstButtonReturn )
        {
            if( [ AppInstaller isInDMG ] == NO )
            {
                [ [ NSUserDefaults standardUserDefaults ] setBool: alert.suppressionButton.state == NSOnState forKey: AlertSuppressKey ];
                [ [ NSUserDefaults standardUserDefaults ] synchronize ];
            }
            
            return AppInstallerStatusInstallError;
        }
    }
    
    /* Do we need admin rights? */
    if( [ [ NSFileManager defaultManager ] isWritableFileAtPath: installDir ] )
    {
        /* Existing app */
        if( [ [ NSFileManager defaultManager ] fileExistsAtPath: installPath ] )
        {
            /* Trashes the existing app */
            if( [ AppInstaller moveToTrash: installPath ] == NO )
            {
                [ AppInstaller displayError ];
                
                return AppInstallerStatusInstallError;
            }
        }
        
        /* Copies the new app */
        if( [ [ NSFileManager defaultManager ] copyItemAtPath: [ [ NSBundle mainBundle ] bundlePath ] toPath: installPath error: NULL ] == NO )
        {
            [ AppInstaller displayError ];
            
            return AppInstallerStatusInstallError;
        }
    }
    else
    {
        if
        (
               [ installPath hasSuffix: @".app" ] == NO
            || [ [ installPath stringByTrimmingCharactersInSet: [ NSCharacterSet whitespaceCharacterSet ] ] length ] == 0
            || [ [ installPath stringByTrimmingCharactersInSet: [ NSCharacterSet whitespaceCharacterSet ] ] length ] == 0
        )
        {
            [ AppInstaller displayError ];
            
            return AppInstallerStatusInstallError;
        }
        
        {
            OSStatus            status;
            AuthorizationFlags  flags;
            AuthorizationItem   item;
            AuthorizationRights rights;
            AuthorizationRef    authorizationRef;
            int                 pid;
            int                 exit;
            
            flags  = kAuthorizationFlagDefaults;
            status = AuthorizationCreate
            (
                 NULL,
                 kAuthorizationEmptyEnvironment,
                 flags,
                 &authorizationRef
             );
            
            memset( &item, 0, sizeof( AuthorizationItem ) );
            
            if( status != errAuthorizationSuccess )
            {
                [ AppInstaller displayError ];
                
                return AppInstallerStatusInstallError;
            }
            
            item.name    = kAuthorizationRightExecute;
            rights.count = 1;
            rights.items = &item;
            
            flags  = kAuthorizationFlagDefaults
                   | kAuthorizationFlagInteractionAllowed
                   | kAuthorizationFlagPreAuthorize
                   | kAuthorizationFlagExtendRights;
            status = AuthorizationCopyRights
            (
                 authorizationRef,
                 &rights,
                 NULL,
                 flags,
                 NULL
            );
                
            if( status != errAuthorizationSuccess )
            {
                [ AppInstaller displayError ];
                
                return AppInstallerStatusInstallError;
            }
            
            flags = kAuthorizationFlagDefaults;
            
            /* Existing app */
            if( [ [ NSFileManager defaultManager ] fileExistsAtPath: installPath ] )
            {
                {
                    OSStatus  err;
                    char    * args[ 3 ];
                    
                    args[ 0 ] = "-rf";
                    args[ 1 ] = strdup( installPath.UTF8String );
                    args[ 2 ] = NULL;
                    
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    
                    err = AuthorizationExecuteWithPrivileges
                    (
                        authorizationRef,
                        "/bin/rm",
                        flags,
                        args,
                        NULL
                    );
                    
                    pid = wait( &exit );
                    
                    if( pid == -1 || WIFEXITED( exit ) == 0 )
                    {
                        free( args[ 1 ] );
                        
                        [ AppInstaller displayError ];
                        
                        return AppInstallerStatusInstallError;
                    }
                    
                    free( args[ 1 ] );
                    
                    #pragma clang diagnostic pop
                                
                    if( err != errAuthorizationSuccess )
                    {
                        [ AppInstaller displayError ];
                        
                        return AppInstallerStatusInstallError;
                    }
                }
            }
            
            {
                OSStatus  err;
                char    * args[ 4 ];
                
                args[ 0 ] = "-rf";
                args[ 1 ] = strdup( [ [ NSBundle mainBundle ] bundlePath ].UTF8String );
                args[ 2 ] = strdup( installPath.UTF8String );
                args[ 3 ] = NULL;
                
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                
                err = AuthorizationExecuteWithPrivileges
                (
                    authorizationRef,
                    "/bin/cp",
                    flags,
                    args,
                    NULL
                );
                
                pid = wait( &exit );
                
                if( pid == -1 || WIFEXITED( exit ) == 0 )
                {
                    free( args[ 1 ] );
                    free( args[ 2 ] );
                    
                    [ AppInstaller displayError ];
                    
                    return AppInstallerStatusInstallError;
                }
                
                free( args[ 1 ] );
                free( args[ 2 ] );
                
                #pragma clang diagnostic pop
                            
                if( err != errAuthorizationSuccess )
                {
                    [ AppInstaller displayError ];
                    
                    return AppInstallerStatusInstallError;
                }
            }
        }
    }
    
    if( [ AppInstaller isInDMG ] == NO )
    {
        /* Moves the original app to the trash */
        [ AppInstaller moveToTrash: [ [ NSBundle mainBundle ] bundlePath ] ];
    }
    
    [ [ NSWorkspace sharedWorkspace ] openFile: installPath ];
    [ NSApp terminate: nil ];
    
    return AppInstallerStatusInstallSucessfull;
}

+ ( BOOL )isInApplicationsFolder
{
    NSArray  * paths;
    NSString * path;
    
	paths = NSSearchPathForDirectoriesInDomains( NSApplicationDirectory, NSAllDomainsMask, YES );
    
    /* All Applications directories */
    for( path in paths )
    {
        /* App is in an application directory */
		if( [ [ [ NSBundle mainBundle ] bundlePath ] hasPrefix: path ] )
        {
            return YES;
        }
    }
    
    return NO;
}

+ ( BOOL )isInDMG
{
    return [ [ [ NSBundle mainBundle ] bundlePath ] hasPrefix: @"/Volumes/ccache" ];
}

+ ( BOOL )isWriteable
{
    return [ [ NSFileManager defaultManager ] isWritableFileAtPath: [ [ NSBundle mainBundle ] bundlePath ] ];
}

+ ( nullable NSString * )installPath
{
	NSArray * paths;
    BOOL      isDir;
    
    paths = NSSearchPathForDirectoriesInDomains( NSApplicationDirectory, NSLocalDomainMask, YES );
    
    if( paths.count && [ [ NSFileManager defaultManager ] fileExistsAtPath: ( id )( paths.lastObject ) isDirectory: &isDir ] && isDir )
    {
        return paths.lastObject;
    }
    
    return nil;
}

+ ( BOOL )moveToTrash: ( NSString * )path
{
    volatile __block BOOL result;
    volatile __block BOOL complete;
    
    result   = NO;
    complete = NO;
    
    [ [ NSWorkspace sharedWorkspace ] recycleURLs:       @[ [ NSURL fileURLWithPath: path ] ]
                                      completionHandler: ^( NSDictionary * _Nonnull newURLs, NSError * _Nullable error )
        {
            ( void )newURLs;
            
            result   = ( error == nil );
            complete = YES;
        }
    ];
    
    while( complete == NO )
    {
        [ [ NSRunLoop mainRunLoop ] runUntilDate: [ NSDate dateWithTimeIntervalSinceNow: 0.1 ] ];
    }
    
    return result;
}

+ ( void )displayError
{
    NSAlert * alert;
    
    alert                 = [ NSAlert new ];
    alert.messageText     = NSLocalizedString( @"Could not move to \"Applications\" Folder", @"" );
    alert.informativeText = [ NSString stringWithFormat: NSLocalizedString( @"If another version of %@ is installed on your computer, please delete it from your \"Applications\" folder and try again.", @"" ), [ AppInstaller appName ] ];
    
    [ alert addButtonWithTitle: NSLocalizedString( @"OK", @"" ) ];
    [ alert runModal ];
}

+ ( NSString * )appName
{
    return [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleName" ];
}

@end
