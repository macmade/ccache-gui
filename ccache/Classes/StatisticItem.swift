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

import Foundation

class StatisticItem: NSObject
{
    @objc public dynamic var label:   String = ""
    @objc public dynamic var text:    String = ""
    @objc public dynamic var tooltip: String = ""
    
    static public func ==( o1: StatisticItem, o2: StatisticItem ) -> Bool
    {
        if o1 === o2
        {
            return true
        }
        
        if o1.label != o2.label
        {
            return false
        }
        
        if o1.text != o2.text
        {
            return false
        }
        
        if o1.tooltip != o2.tooltip
        {
            return false
        }
        
        return true
    }
    
    override func isEqual( _ object: Any? ) -> Bool
    {
        guard let other = object as? StatisticItem else
        {
            return false
        }
        
        return self == other
    }
    
    public override var description: String
    {
        "\( super.description ) \( self.label ): \( self.text )"
    }
}
