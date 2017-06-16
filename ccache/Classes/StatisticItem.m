/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www.xs-labs.com / www.imazing.com
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
 * @file        StatisticItem.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com / www.imazing.com
 */

#import "StatisticItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface StatisticItem()

@end

NS_ASSUME_NONNULL_END

@implementation StatisticItem

- ( instancetype )init
{
    if( ( self = [ super init ] ) )
    {
        self.label   = @"";
        self.text    = @"";
        self.tooltip = @"";
    }
    
    return self;
}

- ( BOOL )isEqualToStatisticItem: ( StatisticItem * )item
{
    if( [ item isKindOfClass: [ StatisticItem class ] ] == NO )
    {
        return NO;
    }
    
    if( [ self.label isEqualToString: item.label ] == NO )
    {
        return NO;
    }
    
    if( [ self.text isEqualToString: item.text ] == NO )
    {
        return NO;
    }
    
    if( [ self.tooltip isEqualToString: item.tooltip ] == NO && ( self.tooltip != nil && item.tooltip != nil ) )
    {
        return NO;
    }
    
    return YES;
}

- ( BOOL )isEqual: ( id )object
{
    if( object == self )
    {
        return YES;
    }
    
    if( [ object isKindOfClass: [ StatisticItem class ] ] == NO )
    {
        return NO;
    }
    
    return [ self isEqualToStatisticItem: object ];
}

- ( BOOL )isEqualTo: ( id )object
{
    return [ self isEqual: object ];
}

- ( NSUInteger )hash
{
    return [ [ self.label stringByAppendingString: self.text ] stringByAppendingPathExtension: self.tooltip ].hash;
}

- ( NSString * )description
{
    NSString * description;
    
    description = [ super description ];
    
    return [ description stringByAppendingFormat: @" %@: %@", self.label, self.text ];
}

@end
