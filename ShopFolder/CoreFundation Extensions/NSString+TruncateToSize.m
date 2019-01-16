//
//  NSString-truncateToSize.m
//  Fast Fonts
//
//  Created by Stuart Shelton on 28/03/2010.
//  Copyright 2010 Stuart Shelton. All rights reserved.
//

#import "NSString+TruncateToSize.h"

#define kEllipsis @"…"

@implementation NSString (truncateToSize)

- (NSString *)truncateToSize:(NSUInteger)size withFont:(UIFont *)font lineBreakMode:(UILineBreakMode)lineBreakMode
{
	return [self truncateToSize: size withFont: font lineBreakMode: lineBreakMode withStartingAnchor: nil withEndingAnchor: nil];
} /* (NSString *)truncateToSize: withFont: lineBreakMode: */

- (NSString *)truncateToSize:(NSUInteger)size withFont:(UIFont *)font lineBreakMode:(UILineBreakMode)lineBreakMode withAnchor:(NSString *)anchor
{
	return [self truncateToSize: size withFont: font lineBreakMode: lineBreakMode withStartingAnchor: anchor withEndingAnchor: anchor];
} /* (NSString *)truncateToSize: withFont: lineBreakMode: withAnchor: */

- (NSString *)truncateToSize:(NSUInteger)size withFont:(UIFont *)font lineBreakMode:(UILineBreakMode)lineBreakMode
          withStartingAnchor:(NSString *)startingAnchor withEndingAnchor: (NSString *)endingAnchor
{
	if( !( lineBreakMode & (UILineBreakModeHeadTruncation |
                            UILineBreakModeMiddleTruncation |
                            UILineBreakModeTailTruncation) ) )
    {
        NSLog(@"Support truncation: head, middle and tail only");
		return self;
    }

	if( [self sizeWithFont: font].width <= size ) {
//        NSLog(@"No need to truncate: enough space");
		return self;
    }
	
    const int ELLIPSIS_LENGTH = [kEllipsis length];
	
	// Note that this code will find the first occurrence of any given anchor,
	// so be careful when choosing anchor characters/strings...
	NSInteger start = 0;
	if( [startingAnchor length] > 0 ) {
		start = [self rangeOfString: startingAnchor options: NSLiteralSearch].location;
		if( NSNotFound == start ) {
			if( [startingAnchor isEqualToString: endingAnchor] ) {
				return [self truncateToSize: size withFont: font lineBreakMode: lineBreakMode];
			} else {
				return [self truncateToSize: size withFont: font lineBreakMode: lineBreakMode withAnchor: endingAnchor];
            }
		}
	}
	
	NSUInteger end = [self length];
	if( [endingAnchor length] > 0 ) {
		end = [self rangeOfString: endingAnchor options:NSLiteralSearch range:NSMakeRange( start+1, [self length]-start-1 )].location;
		if( NSNotFound == end ) {
			if( [startingAnchor isEqualToString: endingAnchor] ) {
				// Shouldn't ever occur, since filtered out in block above...
				return [self truncateToSize:size withFont:font lineBreakMode:lineBreakMode];
			} else {
				return [self truncateToSize:size withFont:font lineBreakMode:lineBreakMode withAnchor:startingAnchor];
            }
		}
	}

	NSUInteger targetLength = end - start;
	if( [[self substringWithRange: NSMakeRange(start, targetLength)] sizeWithFont:font].width < [kEllipsis sizeWithFont:font].width ) {
		if( startingAnchor || endingAnchor ) {
			return [self truncateToSize: size withFont: font lineBreakMode: lineBreakMode];
		} else {
			return self;
        }
    }
	
	NSMutableString *truncatedString = [[NSMutableString alloc] initWithString: self];
	
	switch( lineBreakMode ) {
		case UILineBreakModeHeadTruncation:
			// Avoid anchor...
			if( startingAnchor ) {
				start++;
            }

			while( targetLength > ELLIPSIS_LENGTH + 1 && [truncatedString sizeWithFont:font].width > size) {
				// Replace our ellipsis and one additional following character with our ellipsis
				NSRange range = NSMakeRange(start, ELLIPSIS_LENGTH + 1);
				[truncatedString replaceCharactersInRange:range withString:kEllipsis];
				targetLength--;
			}
			break;
			
		case UILineBreakModeMiddleTruncation:
            {
                NSUInteger leftEnd = start + (targetLength >> 1);
                NSUInteger rightStart = leftEnd + 1;
                
                if( leftEnd + 1 <= rightStart - 1 ) {
                    break;
                }
                
                // leftPre and rightPost consist of any characters before and beyond
                // any specified anchor(s).
                // left and right are the two halves of the string to be truncated - although
                // the initial split is still performed based upon the length of the
                // (sub)string to be truncated, so we could still make a bad initial split given
                // a short string with predominantly narrow characters on one side and wide
                // characters on the other.
                NSString *leftPre = @"";
                if( startingAnchor ) {
                    leftPre = [truncatedString substringWithRange: NSMakeRange( 0,  start+1 )];
                }

                NSMutableString *left = [NSMutableString stringWithString:
                                         [truncatedString substringWithRange:NSMakeRange((startingAnchor?start+1:start), leftEnd-start )]];
                NSMutableString *right = [NSMutableString stringWithString:
                                          [truncatedString substringWithRange:NSMakeRange(rightStart, end-rightStart)]];
                NSString *rightPost = @"";
                if( endingAnchor ) {
                    rightPost = [truncatedString substringWithRange: NSMakeRange( end, [truncatedString length] - end )];
                }
                
                /* NSLog( @"pre '%@', left '%@', right '%@', post '%@'", leftPre, left, right, rightPost ); */
                // Reassemble substrings
                [truncatedString setString: [NSString stringWithFormat: @"%@%@%@%@%@", leftPre, left, kEllipsis, right, rightPost]];
                
                while( leftEnd > start + 1 && rightStart < end + 1 && [truncatedString sizeWithFont: font].width > size) {
                    CGFloat leftLength = [left sizeWithFont: font].width;
                    CGFloat rightLength = [right sizeWithFont: font].width;
                    
                    // Shorten string of longest width
                    if( leftLength > rightLength ) {
                        [left deleteCharactersInRange: NSMakeRange( [left length] - 1, 1 )];
                        leftEnd--;
                    } else { /* ( leftLength <= rightLength ) */
                        [right deleteCharactersInRange: NSMakeRange( 0, 1 )];
                        rightStart++;
                    }
                    
                    /* NSLog( @"pre '%@', left '%@', right'%@', post '%@'", leftPre, left, right, rightPost ); */
                    [truncatedString setString: [NSString stringWithFormat: @"%@%@%@%@%@", leftPre, left, kEllipsis, right, rightPost]];
                }
            }
			break;
			
		case UILineBreakModeTailTruncation:
			while( targetLength > ELLIPSIS_LENGTH + 1 && [truncatedString sizeWithFont: font].width > size) {
				// Remove last character
				NSRange range = NSMakeRange( --end, 1);
				[truncatedString deleteCharactersInRange: range];
				// Replace original last-but-one (now last) character with our ellipsis...
				range = NSMakeRange( end - ELLIPSIS_LENGTH, ELLIPSIS_LENGTH );
				[truncatedString replaceCharactersInRange: range withString: kEllipsis];
				targetLength--;
			}
			break;
        default:
            break;
	}
	
	NSString *result = [NSString stringWithString: truncatedString];
	return result;
} /* (NSString *)truncateToSize: withFont: lineBreakMode: withStartingAnchor: withEndingAnchor: */

@end
