/*
 * Copyright (c) 2018, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

//
//  PurchasePrice.m
//  PsiCashLib
//

#import <Foundation/Foundation.h>
#import "PurchasePrice.h"

#define CODER_VERSION 1

@implementation PsiCashPurchasePrice

- (NSDictionary<NSString*,NSObject*>*_Nonnull)toDictionary
{
    return @{@"transactionClass": self.transactionClass ? self.transactionClass : NSNull.null,
             @"distinguisher": self.distinguisher ? self.distinguisher : NSNull.null,
             @"price": self.price ? self.price : NSNull.null};
}

// Enable this object to be serializable into NSUserDefaults as NSData
- (instancetype _Nullable)initWithCoder:(NSCoder*_Nonnull)decoder
{
    self = [super init];
    if (!self) {
        return nil;
    }

    // Not checking CODER_VERSION yet

    self.transactionClass = [decoder decodeObjectForKey:@"transactionClass"];
    self.distinguisher = [decoder decodeObjectForKey:@"distinguisher"];
    self.price = [decoder decodeObjectForKey:@"price"];

    return self;
}
- (void)encodeWithCoder:(NSCoder*_Nonnull)encoder
{
    [encoder encodeObject:@CODER_VERSION forKey:@"CODER_VERSION"];
    [encoder encodeObject:self.transactionClass forKey:@"transactionClass"];
    [encoder encodeObject:self.distinguisher forKey:@"distinguisher"];
    [encoder encodeObject:self.price forKey:@"price"];
}

@end

