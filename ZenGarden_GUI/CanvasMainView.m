//
//  CanvasMainView.m
//  ZenGarden_GUI
//
//  Created by Joe White on 03/06/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CanvasMainView.h"

#define DEFAULT_OBJECT_ORIGIN_X 100.0
#define DEFAULT_OBJECT_ORIGIN_Y 100.0
#define DEFAULT_OBJECT_HEIGHT 100.0
#define DEFAULT_OBJECT_WIDTH 300.0

@implementation CanvasMainView

@synthesize editToggleMenuItem;
@synthesize isEditModeOn;
@synthesize zgGraph;
@synthesize zgContext;

// C function
void zgCallbackFunction(ZGCallbackFunction function, void *userData, void *ptr) {
  switch (function) {
    case ZG_PRINT_STD: {
      NSLog(@"%s", ptr);
      break;
    }
    case ZG_PRINT_ERR: {
      NSLog(@"ERROR: %s", ptr);
      break;
    }
    default: {
      NSLog(@"unknown ZGCallbackFunction received: %i", function);
      break;
    }
  }
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
      pdAudio = [[PdAudio alloc] initWithInputChannels:0 OutputChannels:2 blockSize:256
                                         andSampleRate:44100.0];
      [pdAudio play];
      
      zgGraph  = zg_new_empty_graph(pdAudio.zgContext);
      zg_attach_graph(pdAudio.zgContext, zgGraph);
      
      arrayOfObjects = [[NSMutableArray alloc] init];
      isEditModeOn = NO;
      [self resetDrawingSelectors];
      [self resetNewConnection];
    }
    return self;
}

- (void)dealloc {
  [super dealloc];
  [objectView dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
  
  [self drawBackground:self.bounds];
  
  // draw selection path
  selectionPath = [NSBezierPath bezierPathWithRect:selectionRect];
  NSColor *theSelectionColor = [NSColor blackColor];
  CGFloat selectionDashArray[2] = { 5.0, 2.0 };
  [selectionPath setLineWidth:1];
  [selectionPath setLineDash: selectionDashArray count: 2 phase: 0.0];
  [theSelectionColor setStroke];
  [selectionPath stroke];
  
  // draw connection path
  if (drawNewConnection) {
    [[NSColor blackColor] setStroke];
    [NSBezierPath setDefaultLineWidth:newConnectionLineWidth];
    [NSBezierPath strokeLineFromPoint:newConnectionStartPoint
                              toPoint:newConnectionEndPoint];
  }
  
  // draw existing connections
  /*
  for (ObjectView *objectView in arrayOfObjects) {
    for (LetView *outletView in objectView.letArray) {
      if (!outletView.isInlet) { // only consider outlets
        for (LetView *inletView in outletView.connections) {
          NSPoint startPoint = NSMakePoint(NSMidX(outletView.frame), outletView.frame.origin.y + outletView.frame.size.height);
          NSPoint endPoint = NSMakePoint(NSMidX(inletView.frame), inletView.frame.origin.y);
          // draw a line from startPoint to endPoint
        }
      }
    }
  } */
  
}

- (ZGContext *)zgContext {
  return pdAudio.zgContext;
}

- (ZGObject *)addNewObjectToGraphWithInitString:(NSString *)initString withLocation:(NSPoint)location {
  ZGObject *zgObject = zg_new_object(pdAudio.zgContext, zgGraph, (char *) [initString cStringUsingEncoding:NSASCIIStringEncoding]);
  if (zgObject != NULL) {
    zg_add_object(zgGraph, zgObject, (int) location.x, (int) location.y);
  }
  return zgObject;
}

- (void)awakeFromNib {
  [[self window] setAcceptsMouseMovedEvents:YES]; 
} 

- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)isFlipped { return YES; }

- (void)toggleEditMode:(id)sender {
  isEditModeOn = !isEditModeOn;
  [sender setState:isEditModeOn ? NSOnState : NSOffState];
  
  for (ObjectView *object in arrayOfObjects) {
    [object setTextFieldEditable:isEditModeOn];
  }
  [self setNeedsDisplay:YES];
  [self needsDisplay];
}

- (BOOL)isEditModeOn {
  return isEditModeOn;
}

#pragma mark - Key Events

- (void)keyDown:(NSEvent *)theEvent {
  
  // Grabbing backspace AND delete key presses seems like a be-ach
  // http://www.cocoadev.com/index.pl?TrappingTheDeleteKey
  //
  // currently using just backspace and cmd+x (Cut menu item)
  unichar key = [[theEvent characters] characterAtIndex:0];
	
	if (key == NSDeleteCharacter || key == NSBackspaceCharacter)
	{
    [self removeObject:self];
    return;
  }
  [super keyDown:theEvent];
}

#pragma mark - Mouse Events

- (void)mouseDown:(NSEvent *)theEvent {
  selectedObjectsCount = 0;
  for (ObjectView *anObject in arrayOfObjects) {
    selectedObjectsCount++;
    [(ObjectView *)anObject highlightObject:NO];
  }
  if (isEditModeOn) {
    drawSelectionRectangle = YES;
    selectionStartPoint = [self invertYAxis:[theEvent locationInWindow]];
  }
}

- (void)mouseUp:(NSEvent *)theEvent {
  
  NSLog(@"MOUSE UP");
  /* reset let mouse down selector
  for (ObjectView *object in arrayOfObjects) {
    [object setLetMouseDown:NO];
  }
  */
  
  [self resetDrawingSelectors];
  selectionStartPoint = NSMakePoint(0, 0);
  selectionRect = [self rectFromTwoPoints:selectionStartPoint toLocation:NSMakePoint(0, 0)];
  [self setNeedsDisplay:YES];
  [self needsDisplay];

}

- (void)mouseDragged:(NSEvent *)theEvent {
  NSLog(@"Canvas Mouse Dragged");
  NSPoint mousePoint = [self invertYAxis:[theEvent locationInWindow]];
  if (isEditModeOn) {
    if (moveObject) {
      [objectToMove setFrameOrigin:NSMakePoint(mousePoint.x - mousePositionInsideObject.x,
                                               mousePoint.y - mousePositionInsideObject.y)]; 
      return;
    }
    else if (resizeObject) {
      NSLog(@"Resize Object"); 
      return;
    }
    else if (drawSelectionRectangle) {
      selectionRect = [self rectFromTwoPoints:selectionStartPoint toLocation:mousePoint];
      selectedObjectsCount = 0;
      for (ObjectView *anObject in arrayOfObjects) {
        if (NSIntersectsRect(selectionRect, [anObject frame])) {
          selectedObjectsCount++;
          [(ObjectView *)anObject highlightObject:YES];
        }
        else {
          [(ObjectView *)anObject highlightObject:NO];
        }
      }
      [self setNeedsDisplay:YES];
      return;
    }
  }
}

- (void)resetDrawingSelectors {
  drawSelectionRectangle = NO;
  resizeObject = NO;
  moveObject = NO;
}
       
- (NSPoint)invertYAxis:(NSPoint)point {
  point = NSMakePoint(point.x, self.frame.size.height - point.y);
  return point;
}


#pragma mark - Background Drawing

- (void)drawBackground:(NSRect)rect {
  if (isEditModeOn) {
    [[[NSColor blueColor] colorWithAlphaComponent:0.2f] setFill];
    [NSBezierPath fillRect:rect];
  }
  else {
    [[NSColor whiteColor] setFill];
    NSRectFill(rect);
  }
}


#pragma mark - Selection Rectangle Drawing
       
- (void)drawSelectionRectangle:(NSPoint)startPoint toLocation:(NSPoint)endPoint {
  selectionRect = [self rectFromTwoPoints:startPoint toLocation:endPoint];
}
       
- (NSRect)rectFromTwoPoints:(NSPoint)firstPoint toLocation:(NSPoint)secondPoint {
  return NSMakeRect(MIN(firstPoint.x, secondPoint.x),
                    MIN(firstPoint.y, secondPoint.y),
                    fabs(firstPoint.x - secondPoint.x),
                    fabs(firstPoint.y - secondPoint.y));
} 


#pragma mark - Object Drawing

-(IBAction)putObject:(id)sender {
  // make sure edit mode is on 
  if (!isEditModeOn) {
    [self toggleEditMode:[self menu]];
    [editToggleMenuItem setState:NSOnState];
  }
  // Convert mouse location to view coordinates
  NSPoint mouseLocation = [[self window] convertScreenToBase:[NSEvent mouseLocation]];
  NSPoint viewLocation = [self convertPoint:mouseLocation fromView:nil];
  
  // If inside canvas view add object at mouse location
  if (NSPointInRect(viewLocation, [self bounds])) {
    objectView = [[ObjectView alloc] 
                   initWithFrame:NSMakeRect(viewLocation.x - (DEFAULT_OBJECT_WIDTH / 2),
                                            viewLocation.y - (DEFAULT_OBJECT_HEIGHT / 2),
                                            DEFAULT_OBJECT_WIDTH,
                                            DEFAULT_OBJECT_HEIGHT) delegate:self];
    [self addSubview:objectView];
    [arrayOfObjects addObject:objectView];
  }
  // If outside canvas view add object at default location
  else {
    objectView = [[ObjectView alloc] initWithFrame:NSMakeRect(DEFAULT_OBJECT_ORIGIN_X,
                                                                       DEFAULT_OBJECT_ORIGIN_Y,
                                                                       DEFAULT_OBJECT_WIDTH,
                                                                       DEFAULT_OBJECT_HEIGHT) delegate:self];
    [self addSubview:objectView];
    [arrayOfObjects addObject:objectView];
  }
}

- (IBAction)removeObject:(id)sender { 
  // Removes all highlighted objects
  for (ObjectView *object in arrayOfObjects) {
    if ([object isHighlighted]) {
      [object removeZGObjectFromZGGraph:zgGraph];
      [object removeFromSuperview];
    }
  }
} 

- (IBAction)selectAll:(id)sender {
  // Highlights all objects
  for (ObjectView *object in arrayOfObjects) {
    [object highlightObject:YES];
  }
}

- (void)moveObject:(ObjectView *)object with:(NSPoint)adjustedMousePosition {
  moveObject = YES;
  objectToMove = object;
  mousePositionInsideObject = adjustedMousePosition;
}


#pragma mark - Connection Drawing

- (void)startNewConnectionDrawingFromLet:(LetView *)aLetView {
  
  ObjectView *fromObject = (ObjectView *)aLetView.superview;
  
  // Set a thicker line for signal connections
  if (zg_get_connection_type([fromObject zgObject], (unsigned int) [[fromObject outletArray] indexOfObject:aLetView]) == DSP) {
    newConnectionLineWidth = 3;
  }
  else {
    newConnectionLineWidth = 1;
  }

  // Start connection drawing from mid point of let view
  newConnectionStartPoint = NSMakePoint([fromObject frame].origin.x + [aLetView frame].origin.x + NSMidX([aLetView bounds]),
                                        [fromObject frame].origin.y + [aLetView frame].origin.y + NSMidY([aLetView bounds]));
  drawNewConnection = YES;
}

- (void)setNewConnectionEndPointFromEvent:(NSEvent *)theEvent {
  
  newConnectionEndPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  for (ObjectView *anObject in arrayOfObjects) {
    for (LetView *aLetView in anObject.inletArray) {
      if (NSPointInRect(newConnectionEndPoint, [self convertRect:[aLetView bounds] fromView:aLetView])) {
        // Inlet!
        newConnectionEndPoint = NSMakePoint([anObject frame].origin.x + [aLetView frame].origin.x + NSMidX([aLetView bounds]),
                                              [anObject frame].origin.y + [aLetView frame].origin.y + NSMidY([aLetView bounds]));
      }
      else {
        // Not an inlet     
      }
    }
  }
  [self setNeedsDisplay:YES];
  [self needsDisplay];
}

- (void)endNewConnectionDrawingFromLet:(LetView *)fromLetView withEvent:(NSEvent *)theEvent {

  ObjectView *fromObject = (ObjectView *)fromLetView.superview;
  ObjectView *toObject = nil;
  LetView *toLetView = nil;
  
  newConnectionEndPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  for (ObjectView *anObject in arrayOfObjects) {
    for (LetView *aLetView in anObject.inletArray) {
      if (NSPointInRect(newConnectionEndPoint, [self convertRect:[aLetView bounds] fromView:aLetView])) {
        // Is a valid inlet
        toObject = anObject;
        toLetView = aLetView;
        newConnectionEndPoint = NSMakePoint([anObject frame].origin.x + [aLetView frame].origin.x + NSMidX([aLetView bounds]),
                                            [anObject frame].origin.y + [aLetView frame].origin.y + NSMidY([aLetView bounds]));
        zg_add_connection(zgGraph,
                          [fromObject zgObject], (unsigned int) [[fromObject outletArray] indexOfObject:fromLetView],
                          [toObject zgObject], (unsigned int) [[toObject inletArray] indexOfObject:toLetView]);
  
        [self setNeedsDisplay:YES];
        [self needsDisplay];
        return;
      }
      else {
        // Not an inlet     
      }
    }
  }
  [self resetNewConnection];
  [self setNeedsDisplay:YES];
  [self needsDisplay];
}

- (void)resetNewConnection { 
  drawNewConnection = NO;
  newConnectionEndPoint = NSMakePoint(0, 0);
  newConnectionStartPoint = NSMakePoint(0 , 0);
  newConnectionLineWidth = 1;
}

@end
