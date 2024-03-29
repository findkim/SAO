//
//  CSVParser.m
//  SAO
//
//  Created by Sean Fitzgerald on 5/17/13.
//  Copyright (c) 2013 Sean T Fitzgerald. All rights reserved.
//

#import "CSVParser.h"

@interface CSVParser () <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, strong) NSArray * lines;
@property BOOL continueParsing;
@property int lineNumber;
@property int columnNumber;
@property BOOL parserReady;

@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * password;
@property (nonatomic, strong) NSURLConnection * connection;
@property (nonatomic, strong) NSMutableData * receivedData;

@end

@implementation CSVParser

#pragma mark -
#pragma mark Public methods

//loads a CSV file into memory
-(void)loadCSVFileWithResourceName:(NSString *)filename;
{
	NSString* pathT = [[NSBundle mainBundle] pathForResource:filename
																										ofType:@"csv"];
	NSString* contentT = [NSString stringWithContentsOfFile:pathT
																								 encoding:NSUTF8StringEncoding
																										error:NULL];
	self.lines = [contentT componentsSeparatedByString:@"\r"];
	self.lineNumber = 0;
	[self.delegate parserLoaded:self];
}

-(void)loadCSVTableWithString:(NSString *)tableString
{
	self.lines = [tableString componentsSeparatedByString:@"\r"];
	self.lineNumber = 0;
	[self.delegate parserLoaded:self];
}

-(void)loadCSVFileWithFilePath:(NSString *)path
{
    NSStringEncoding encoding = 0;
	NSError* error;
	self.lines = [[NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&error] componentsSeparatedByString:@"\r"];
	self.lineNumber = 0;
	[self.delegate parserLoaded:self];
}

-(void)loadCSVFileFromURL:(NSURL *)url
{
	NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
	self.connection = [[NSURLConnection alloc] initWithRequest:requestObj delegate:self];
	NSLog(@"request sent");
	self.receivedData = [[NSMutableData alloc] init];
}

/******************************************/
//STARTING CONNECTION STUFF//

//- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
//{
//	NSLog(@"got authorization challenge");
//	
//	if ([challenge previousFailureCount] == 0) {
//		
//		[[challenge sender] useCredential:[NSURLCredential credentialWithUser:self.username
//																																 password:self.password persistence:NSURLCredentialPersistencePermanent] forAuthenticationChallenge:challenge];
//		
//	} else {
//		[[challenge sender] cancelAuthenticationChallenge:challenge];
//		[[[UIAlertView alloc] initWithTitle:@"Invalid Username/Password"
//																message:@"Please try again."
//															 delegate:nil
//											cancelButtonTitle:@"OK"
//											otherButtonTitles: nil] show];
//	}
//}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
{
	NSLog(@"received response via nsurlconnection");
}

- ( void )connectionDidFinishLoading: (NSURLConnection *)connection
{
    NSStringEncoding encoding = NSASCIIStringEncoding;
    NSString *loadedFile = [[NSString alloc] initWithData:self.receivedData encoding:encoding];
//    NSLog(@"loadedData: %@", loadedFile);
    
//    NSArray *contentArray = [fileString componentsSeparatedByString:@"\r"];
//    NSLog(@"%@",loadedFile);
    
    
//    for (NSString *item in contentArray) {
//        NSArray *itemArray = [item componentsSeparatedByString:@","];
    
    
	self.lines = [loadedFile componentsSeparatedByString:@"\r"];
	self.lineNumber = 0;
	[self.delegate parserLoaded:self];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"%@", [error description]);
}

- ( void )connection: (NSURLConnection *)connection didReceiveData: (NSData *)data
{
	// receivedData is an NSMutableData object
	[self.receivedData appendData: data ];
}

//DONE WITH CONNECTION STUFF//
/******************************************/

//start the parsing or parse in separate queue;
-(void)parse
{
	self.isParsing = YES;
	self.continueParsing = YES;
	if ([self.delegate respondsToSelector:@selector(didStartParsingFile:)]) {
		[self.delegate parserDidStartParsingFile:self];
	}
	
	NSMutableString * currentValue = [[NSMutableString alloc] init];
	for (; self.lineNumber < [self.lines count]; self.lineNumber++)
	{
//        NSLog(@"NEW LINEEEE %i", self.lineNumber);
		//finds the string at the specific line number
		NSString * line = (NSString *)self.lines[self.lineNumber];
		
		BOOL inQuotes = NO;
		BOOL quoteLastRun = NO;
		
		for (int i = 0; i < [line length] && self.continueParsing; i++)
		{
			//get the current character
			char currentCharacter = [line characterAtIndex:i];
            char nextCharacter;
            if (i+1 < [line length]) {
                nextCharacter = [line characterAtIndex:i+1];
            }
//			NSLog(@"%c", currentCharacter);
			//look for special characters
            
            if (currentCharacter == '"')
            {
                // End of quote, next column
                if (inQuotes && nextCharacter == ',') {
                    quoteLastRun = YES;
                    inQuotes = NO;
//                    NSLog(@"Getting out of quote");
                    [self.delegate parser:self
                           DidParseString:[currentValue copy]
                            withRowNumber:self.lineNumber
                          withColumNumber:self.columnNumber];
                    currentValue = [[NSMutableString alloc] init];
//                    NSLog(@"Leaving quote: New element: %i", self.columnNumber);
                    self.columnNumber++;
                    i++;
                
                // literal character " within ""
                } else if (nextCharacter == '"') {
                    [currentValue appendFormat:@"%c", currentCharacter];//literal character
                    i++;
                } else {
                    inQuotes = YES;
//                    NSLog(@"Going into quote");
                }
            } else {
                if (inQuotes) {
                    [currentValue appendFormat:@"%c", currentCharacter];//literal character
                } else {    //not in quotes
					if (currentCharacter == ',')
					{
//                        NSLog(@"New Element: %i", self.columnNumber);
						/********************** NEW VALUE **********************/
						[self.delegate parser:self
                               DidParseString:[currentValue copy]
                                withRowNumber:self.lineNumber
                              withColumNumber:self.columnNumber];
						currentValue = [[NSMutableString alloc] init];
						self.columnNumber++;
					}//splitting values
					else [currentValue appendFormat:@"%c", currentCharacter];//literal character
				}
                
            }
            
//  SEAN'S PARSING ERROR WITH MULTIPLE COMMAS
//			if (currentCharacter == '"')
//			{//4 options: it is starting a literal, it is ending a literal, it is the first in a double, it is the second in a double
//				if (inQuotes)
//				{//3 options: it is ending a literal, it is first in a double, or it is second in a double
//					if (quoteLastRun)
//					{//it is second in a double - append the quotation mark
//						[currentValue appendFormat:@"%c", currentCharacter];
//						quoteLastRun = NO;
//					} else //it is first in a double or it is ending a literal - do nothing, but remember it...
//					{
//						quoteLastRun = YES;
//                        NSLog(@"Getting out of quote");
//					}
//				} else
//				{//1 option: it is starting a literal
//					inQuotes = YES;
//				}
//			} else
//			{
//				//2 options: inside quotes, outside quotes
//				if (inQuotes)
//				{ //in quotes
//					if (quoteLastRun)
//					{// those last quotes were ending the literal, so proceed as if you weren't in quotes
//						inQuotes = NO;
//						if (currentCharacter == ',')
//						{
// 
//							/********************** NEW VALUE **********************/
//							[self.delegate parser:self
//										 DidParseString:[currentValue copy]
//											withRowNumber:self.lineNumber
//										withColumNumber:self.columnNumber];
//							currentValue = [[NSMutableString alloc] init];
//							self.columnNumber++;
//						}//splitting values
//						else [currentValue appendFormat:@"%c", currentCharacter];//literal character
//						
//					} else [currentValue appendFormat:@"%c", currentCharacter];//literal character
//				}
//				else
//				{//not in quotes
//					if (currentCharacter == ',')
//					{
//                        NSLog(@"this didn't work %c", currentCharacter);
//						/********************** NEW VALUE **********************/
//						[self.delegate parser:self
//									 DidParseString:[currentValue copy]
//										withRowNumber:self.lineNumber
//									withColumNumber:self.columnNumber];
//						currentValue = [[NSMutableString alloc] init];
//						self.columnNumber++;
//					}//splitting values
//					else [currentValue appendFormat:@"%c", currentCharacter];//literal character
//				}
//			}
		}
		if (!self.continueParsing)
		{
			return;
		}
		/********************** NEW VALUE **********************/
		[self.delegate parser:self
					 DidParseString:[currentValue copy]
						withRowNumber:self.lineNumber
					withColumNumber:self.columnNumber];
		currentValue = [[NSMutableString alloc] init];
		self.columnNumber = 0;
		if ([self.delegate respondsToSelector:@selector(parserDidFinishRow:)])
		{
			[self.delegate parserDidFinishRow:self];
		}
	}
	[self.delegate parserDidFinishParsingFile:self];
	self.isParsing = NO;
}

-(void)parseInQueue:(dispatch_queue_t) queue
{
	dispatch_async(queue, ^{
		[self parse];
	});
}

-(void)parseInBackground
{
	[self parseInQueue:dispatch_queue_create("parsing queue", NULL)];
}

//pause the parsing
-(void)pause
{
	self.continueParsing = NO;
}

//rewind the document so that another call of parse will start at the beginning
-(void)rewind
{
	self.continueParsing = NO;
	self.columnNumber = self.lineNumber = 0;
}

#pragma mark -
#pragma mark Private methods

@end
