//
//  NSString-truncateToSize.h
//  Fast Fonts
//
//  Created by Stuart Shelton on 28/03/2010.
//  Copyright 2010 Stuart Shelton. All rights reserved.
//

@interface NSString (truncateToSize)

- (NSString *)truncateToSize:(NSUInteger)size withFont:(UIFont *)font lineBreakMode:(UILineBreakMode)lineBreakMode;
- (NSString *)truncateToSize:(NSUInteger)size withFont:(UIFont *)font lineBreakMode:(UILineBreakMode)lineBreakMode withAnchor:(NSString *)anchor;
- (NSString *)truncateToSize:(NSUInteger)size withFont:(UIFont *)font lineBreakMode:(UILineBreakMode)lineBreakMode withStartingAnchor:(NSString *)startingAnchor withEndingAnchor:(NSString *)endingAnchor;

@end
