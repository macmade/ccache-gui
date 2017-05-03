/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www.xs-labs.com
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
 * @file        CCache.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com
 */

#import "CCache.h"

static void init( void ) __attribute__( ( constructor ) );

NS_ASSUME_NONNULL_BEGIN

@interface CCache()

@property( atomic, readwrite, assign           ) BOOL       installed;
@property( atomic, readwrite, strong, nullable ) NSString * path;

- ( void )execute: ( NSArray< NSString * > * )arguments completion: ( void ( ^ )( int status, NSFileHandle * _Nullable output, NSFileHandle * _Nullable error ) )completion;

@end

NS_ASSUME_NONNULL_END

@implementation CCache

+ ( instancetype )sharedInstance
{
    static dispatch_once_t once;
    static id              instance;
    
    dispatch_once
    (
        &once,
        ^( void )
        {
            instance = [ self new ];
        }
    );
    
    return instance;
}

- ( instancetype )init
{
    NSString     * shell;
    NSTask       * task;
    NSPipe       * pipe;
    NSString     * output;
    
    if( ( self = [ super init ] ) )
    {
        shell = [ NSProcessInfo processInfo ].environment[ @"SHELL" ];
        
        if( shell.length && [ [ NSFileManager defaultManager ] fileExistsAtPath: shell ] )
        {
            pipe                = [ NSPipe pipe ];
            task                = [ NSTask new ];
            task.launchPath     = shell;
            task.arguments      = @[ @"-l", @"-c", @"which ccache" ];
            task.standardOutput = pipe;
            
            [ task launch ];
            [ task waitUntilExit ];
            
            if( task.terminationStatus == EXIT_SUCCESS )
            {
                output = [ [ NSString alloc ] initWithData: [ pipe.fileHandleForReading readDataToEndOfFile ] encoding: NSUTF8StringEncoding ];
                output = [ output stringByTrimmingCharactersInSet: [ NSCharacterSet whitespaceAndNewlineCharacterSet ] ];
                
                if( output.length && [ [ NSFileManager defaultManager ] fileExistsAtPath: output ] )
                {
                    self.path      = output;
                    self.installed = YES;
                }
            }
        }
    }
    
    return self;
}

- ( void )cleanup: ( nullable void ( ^ )( BOOL success ) )completion
{
    [ self execute: @[ @"-c" ] completion: ^( int status, NSFileHandle * _Nullable output, NSFileHandle * _Nullable error )
        {
            ( void )output;
            ( void )error;
            
            if( completion )
            {
                completion( status == 0 );
            }
        }
    ];
}


- ( void )clear: ( nullable void ( ^ )( BOOL success ) )completion
{
    [ self execute: @[ @"-C" ] completion: ^( int status, NSFileHandle * _Nullable output, NSFileHandle * _Nullable error )
        {
            ( void )output;
            ( void )error;
            
            if( completion )
            {
                completion( status == 0 );
            }
        }
    ];
}

- ( void )clearStatistics: ( nullable void ( ^ )( BOOL success ) )completion
{
    [ self execute: @[ @"-z" ] completion: ^( int status, NSFileHandle * _Nullable output, NSFileHandle * _Nullable error )
        {
            ( void )output;
            ( void )error;
            
            if( completion )
            {
                completion( status == 0 );
            }
        }
    ];
}

- ( void )getStatistics: ( nullable void ( ^ )( BOOL success, NSString * statistics ) )completion
{
    [ self execute: @[ @"-s" ] completion: ^( int status, NSFileHandle * _Nullable output, NSFileHandle * _Nullable error )
        {
            ( void )error;
            
            if( completion == NULL )
            {
                return;
            }
            
            if( status == 0 )
            {
                completion( YES, [ [ NSString alloc ] initWithData: [ output readDataToEndOfFile ] encoding: NSUTF8StringEncoding ] );
            }
            else
            {
                completion( NO, @"" );
            }
        }
    ];
}

- ( void )execute: ( NSArray< NSString * > * )arguments completion: ( void ( ^ )( int status, NSFileHandle * _Nullable output, NSFileHandle * _Nullable error ) )completion
{
    if( self.installed == NO )
    {
        completion( EXIT_FAILURE, nil, nil );
        
        return;
    }
    
    dispatch_async
    (
        dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ),
        ^( void )
        {
            NSTask * task;
            NSPipe * p1;
            NSPipe * p2;
            
            task = [ NSTask new ];
            p1   = [ NSPipe pipe ];
            p2   = [ NSPipe pipe ];
            
            task.launchPath     = self.path;
            task.arguments      = arguments;
            task.standardOutput = p1;
            task.standardError  = p2;
            
            [ task launch ];
            [ task waitUntilExit ];
            
            dispatch_async
            (
                dispatch_get_main_queue(),
                ^( void )
                {
                    completion( task.terminationStatus, p1.fileHandleForReading, p2.fileHandleForReading );
                }
            );
        }
    );
}

@end

static void init( void )
{
    [ CCache sharedInstance ];
}
