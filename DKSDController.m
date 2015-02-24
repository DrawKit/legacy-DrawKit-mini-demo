//
//  DKSDController.m
//  GCDrawKit
//
//  Created by graham on 19/06/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import "DKSDController.h"
#import <DKDrawKit/DKDrawKit.h>

@implementation DKSDController


- (IBAction)	toolMatrixAction:(id) sender
{
	// the drawing view can handle this for us, provided we pass it an object that responds to -title and returns
	// the valid name of a registered tool. The selected button cell is just such an object.
	
	NSButtonCell* cell = [sender selectedCell];
	[mDrawingView selectDrawingToolByName:cell];
}


- (IBAction)	toolStickyAction:(id) sender
{
	// sets the tool controller's flag to the inverted state of the checkbox
	
	[(DKToolController*)[mDrawingView controller] setAutomaticallyRevertsToSelectionTool:![sender intValue]];
}


#pragma mark -

- (IBAction)	styleFillColourAction:(id) sender
{
	// get the style of the selected object
	
	DKStyle* style = [self styleOfSelectedObject];
	[style setFillColour:[sender color]];
	[[mDrawingView undoManager] setActionName:@"Change Fill Colour"];
}




- (IBAction)	styleStrokeColourAction:(id) sender
{
	// get the style of the selected object
	
	DKStyle* style = [self styleOfSelectedObject];
	[style setStrokeColour:[sender color]];
	[[mDrawingView undoManager] setActionName:@"Change Stroke Colour"];
}




- (IBAction)	styleStrokeWidthAction:(id) sender
{
	// get the style of the selected object
	
	DKStyle* style = [self styleOfSelectedObject];
	[style setStrokeWidth:[sender floatValue]];
	
	// synchronise the text field and the stepper so they both have the same value
	
	if( sender == mStyleStrokeWidthStepper )
		[mStyleStrokeWidthTextField setFloatValue:[sender floatValue]];
	else
		[mStyleStrokeWidthStepper setFloatValue:[sender floatValue]];
	
	[[mDrawingView undoManager] setActionName:@"Change Stroke Width"];
}


- (IBAction)	styleFillCheckboxAction:(id) sender
{
	// get the style of the selected object

	DKStyle* style = [self styleOfSelectedObject];
	
	BOOL removing = ([sender intValue] == 0);
	
	if ( removing )
	{
		[style setFillColour:nil];
		[[mDrawingView undoManager] setActionName:@"Delete Fill"];
	}
	else
	{
		[style setFillColour:[mStyleFillColourWell color]];
		[[mDrawingView undoManager] setActionName:@"Add Fill"];
	}
}


- (IBAction)	styleStrokeCheckboxAction:(id) sender
{
	// get the style of the selected object

	DKStyle* style = [self styleOfSelectedObject];
	
	BOOL removing = ([sender intValue] == 0);
	
	if ( removing )
	{
		[style setStrokeColour:nil];
		[[mDrawingView undoManager] setActionName:@"Delete Stroke"];
	}
	else
	{
		[style setStrokeColour:[mStyleStrokeColourWell color]];
		[[mDrawingView undoManager] setActionName:@"Add Stroke"];
	}
}


#pragma mark -

- (IBAction)	gridMatrixAction:(id) sender
{
	// the drawing's grid layer already knows how to do this - just pass it the selected cell from where it
	// can extract the tag which it interprets as one of the standard grids.
	
	[[[mDrawingView drawing] gridLayer] setMeasurementSystemAction:[sender selectedCell]];
}


- (IBAction)	snapToGridAction:(id) sender
{
	// set the drawing's snapToGrid flag to match the sender's state
	
	[[mDrawingView drawing] setSnapsToGrid:[sender intValue]];
}


#pragma mark -

- (IBAction)	layerAddButtonAction:(id) sender
{
	// adding a new layer - first create it

	DKObjectDrawingLayer* newLayer = [[DKObjectDrawingLayer alloc] init];
	
	// add it to the drawing and make it active - this triggers notifications which update the UI
	
	[[mDrawingView drawing] addLayer:newLayer andActivateIt:YES];
	
	// drawing now owns the layer so we can release it
	
	[newLayer release];
	
	// inform the Undo Manager what we just did:
	
	[[mDrawingView undoManager] setActionName:@"New Drawing Layer"];
}




- (IBAction)	layerRemoveButtonAction:(id) sender
{
	// removing the active (selected) layer - first find that layer
	
	DKLayer* activeLayer = [[mDrawingView drawing] activeLayer];
	
	// remove it and activate another (passing nil tells the drawing to use its nous to activate something sensible)
	
	[[mDrawingView drawing] removeLayer:activeLayer andActivateLayer:nil];
	
	// inform the Undo Manager what we just did:
	
	[[mDrawingView undoManager] setActionName:@"Delete Drawing Layer"];
}


#pragma mark -



- (void)		drawingSelectionDidChange:(NSNotification*) note
{
	// the selection changed within the drawing - update the UI to match the state of whatever was selected. We pass nil
	// because in fact we just grab the current selection directly.
	
	[self updateControlsForSelection:nil];
}


- (void)		activeLayerDidChange:(NSNotification*) note
{
	// change the selection in the layer table to match the actual layer that has been activated
	
	DKDrawing* dwg = [mDrawingView drawing];
	
	if( dwg != nil )
	{
		// now find the active layer's index and set the selection to the same value
		
		unsigned index = [dwg indexOfLayer:[dwg activeLayer]];
		
		if( index != NSNotFound )
			[mLayerTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	}
}


- (void)		numberOfLayersChanged:(NSNotification*) note
{
	// update the table to match the number of layers in the drawing
	
	[mLayerTable reloadData];
	
	// re-establish the correct selection - requires a small delay so that the table is fully reloaded before the
	// selection is changed to avoid a potential out of range exception.
	
	[self performSelector:@selector(activeLayerDidChange:) withObject:nil afterDelay:0.0];
}


- (void)		selectedToolDidChange:(NSNotification*) note
{
	// the selected tool changed - find out which button cell matches and select it so that
	// the tool UI and the actual selected tool agree. This is necessary because when a tool is automatically
	// "sprung back" the UI needs to keep up with that automatic change.
	
	// which tool was selected?
	
	DKDrawingTool*	tool = [[note object] drawingTool];
	NSString*		toolName = [tool registeredName];
	
	// keep the "sticky" checkbox synchronised with the tool controller's actual state
	
	BOOL sticky = ![(DKToolController*)[mDrawingView controller] automaticallyRevertsToSelectionTool];
	[mToolStickyCheckbox setIntValue:sticky];
	
	// search through the matrix to find the cell whose title matches the tool's name,
	// and select it.
	
	int				row, col, rr, cc;
	NSCell*			cell;
	
	[mToolMatrix getNumberOfRows:&row columns:&col];
	
	for( rr = 0; rr < row; ++rr )
	{
		for( cc = 0; cc < col; ++cc )
		{
			cell = [mToolMatrix cellAtRow:rr column:cc];
			
			if([[cell title] isEqualToString:toolName])
			{
				[mToolMatrix selectCellAtRow:rr column:cc];
				return;
			}
		}
	}
	
	[mToolMatrix selectCellAtRow:0 column:0];
}


#pragma mark -

- (void)		updateControlsForSelection:(NSArray*) selection
{
	// update all necessary UI controls to match the state of the selected object. Note that this ignores the selection passed to it
	// and just gets the info directly. It also doesn't bother to worry about more than one selected object - it just uses the info from
	// the topmost object - for this simple demo that's sufficient.
	
	// get the selected object's style
	
	DKStyle*		style = [self styleOfSelectedObject];
	DKRasterizer*	rast;
	NSColor*		temp;
	float			sw;
	
	// set up the fill controls if the style has a fill property, or disable them
	// altogether if it does not.
	
	if([style hasFill])
	{
		rast = [[style renderersOfClass:[DKFill class]] lastObject];
		temp = [(DKFill*)rast colour];
		[mStyleFillColourWell setEnabled:YES];
		[mStyleFillCheckbox setIntValue:YES];
	}
	else
	{
		temp = [NSColor whiteColor];
		[mStyleFillColourWell setEnabled:NO];
		[mStyleFillCheckbox setIntValue:NO];
	}	
	[mStyleFillColourWell setColor:temp];
	
	// set up the stroke controls if the style has a stroke property, or disable them
	// altogether if it does not.

	if([style hasStroke])
	{
		rast = [[style renderersOfClass:[DKStroke class]] lastObject];
		temp = [(DKStroke*)rast colour];
		sw = [(DKStroke*)rast width];
		[mStyleStrokeColourWell setEnabled:YES];
		[mStyleStrokeWidthStepper setEnabled:YES];
		[mStyleStrokeWidthTextField setEnabled:YES];
		[mStyleStrokeCheckbox setIntValue:YES];
	}
	else
	{
		temp = [NSColor whiteColor];
		sw = 1.0;
		[mStyleStrokeColourWell setEnabled:NO];
		[mStyleStrokeWidthStepper setEnabled:NO];
		[mStyleStrokeWidthTextField setEnabled:NO];
		[mStyleStrokeCheckbox setIntValue:NO];
	}
	
	[mStyleStrokeColourWell setColor:temp];
	[mStyleStrokeWidthStepper setFloatValue:sw];
	[mStyleStrokeWidthTextField setFloatValue:sw];
}


- (DKStyle*)	styleOfSelectedObject
{
	// returns the style of the topmost selected object in the active layer, or nil if there is nothing selected.
	
	DKStyle* selectedStyle = nil;
	
	// get the active layer, but only if it's one that supports drawable objects
	
	DKObjectDrawingLayer* activeLayer = [[mDrawingView drawing] activeLayerOfClass:[DKObjectDrawingLayer class]];
	
	if( activeLayer != nil )
	{
		// get the selected objects and use the style of the last object, corresponding to the
		// one drawn last, or on top of all the others.
		
		NSArray* selectedObjects = [activeLayer selectedAvailableObjects];
		
		if(selectedObjects != nil && [selectedObjects count] > 0 )
		{
			selectedStyle = [(DKDrawableObject*)[selectedObjects lastObject] style];
			
			[selectedStyle setLocked:NO];	// ensure it can be edited
		}
	}
	
	return selectedStyle;
}


#pragma mark -
#pragma mark - as a NSWindowController

- (void)		awakeFromNib
{
	// make sure the view has a drawing object initialised. While the view itself would do this for us later, we tip its hand now so that we definitely
	// have a valid DKDrawing object available for setting up the notifications and user interface. In this case we are simply allowing the view to
	// create and own the drawing, rather than owning it here - though that would also be a perfectly valid way to do things.
	
	[mDrawingView createAutomaticDrawing];
	
	// subscribe to selection, layer and tool change notifications so that we can update the UI when these change
	
	
	[[NSNotificationCenter defaultCenter]	addObserver:self
											selector:@selector(drawingSelectionDidChange:)
											name:kDKLayerSelectionDidChange
											object:nil];

	[[NSNotificationCenter defaultCenter]	addObserver:self
											selector:@selector(drawingSelectionDidChange:)
											name:kDKStyleDidChangeNotification
											object:nil];
											
	[[NSNotificationCenter defaultCenter]	addObserver:self
											selector:@selector(activeLayerDidChange:)
											name:kDKDrawingActiveLayerDidChange
											object:[mDrawingView drawing]];
											
	[[NSNotificationCenter defaultCenter]	addObserver:self
											selector:@selector(numberOfLayersChanged:)
											name:kDKLayerGroupNumberOfLayersDidChange
											object:[mDrawingView drawing]];

	[[NSNotificationCenter defaultCenter]	addObserver:self
											selector:@selector(selectedToolDidChange:)
											name:kDKDidChangeToolNotification
											object:nil];

	// creating the drawing set up the initial active layer but we weren't ready to listen to that notification. So that we can set
	// up the user-interface correctly this first time, just call the responder method directly now.
	
	[self activeLayerDidChange:nil];
	[[mDrawingView window] makeFirstResponder:mDrawingView];
}



#pragma mark -
#pragma mark - as the TableView dataSource


- (int)			numberOfRowsInTableView:(NSTableView*) aTable
{
	return [[mDrawingView drawing] countOfLayers];
}


- (id)			tableView:(NSTableView *)aTableView
				objectValueForTableColumn:(NSTableColumn *)aTableColumn
				row:(int)rowIndex
{
	return [[[[mDrawingView drawing] layers] objectAtIndex:rowIndex] valueForKey:[aTableColumn identifier]];
}


- (void)		tableView:(NSTableView *)aTableView
				setObjectValue:anObject
				forTableColumn:(NSTableColumn *)aTableColumn
				row:(int)rowIndex
{
	DKLayer* layer = [[[mDrawingView drawing] layers] objectAtIndex:rowIndex];
	[layer setValue:anObject forKey:[aTableColumn identifier]];
}

#pragma mark -
#pragma mark - as the TableView delegate

- (void)				tableViewSelectionDidChange:(NSNotification*) aNotification
{
	// when the user selects a different layer in the table, change the real active layer to match.
	
	if ([aNotification object] == mLayerTable)
	{
		int row = [mLayerTable selectedRow];
		
		if ( row != -1 )
			[[mDrawingView drawing] setActiveLayer:[[mDrawingView drawing] objectInLayersAtIndex:row]];
	}
}


#pragma mark -
#pragma mark - as the NSApplication delegate

- (void)		applicationDidFinishLaunching:(NSNotification*) aNotification
{
	// app ready to go - first turn off all style sharing. For this simple demo this makes life a bit easier.
	// (note - comment out this line and see what happens. It's perfectly safe ;-)
	
	[DKStyle setStylesAreSharableByDefault:NO];

	// set up an initial style to apply to all new objects created. Because sharin gis off above, this style is copied
	// for each new object created, so each has its own individual style which can be edited independently.
	
	DKStyle* ds = [DKStyle styleWithFillColour:[NSColor orangeColor] strokeColour:[NSColor blackColor] strokeWidth:2.0];
	[ds setName:@"Demo Style"];
	
	[DKObjectCreationTool setStyleForCreatedObjects:ds];
	
	// register the default set of tools (Select, Rectangle, Oval, etc)
	
	[DKDrawingTool registerStandardTools];
}


- (IBAction)	saveDocumentAs:(id) sender
{
	NSSavePanel* sp = [NSSavePanel savePanel];
	
	[sp setRequiredFileType:@"pdf"];
	[sp setCanSelectHiddenExtension:YES];
	
	[sp beginSheetForDirectory:nil
		file:[[self window] title]
		modalForWindow:[self window]
		modalDelegate:self
		didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
}


- (void)		savePanelDidEnd:(NSSavePanel*) panel returnCode:(int) returnCode contextInfo:(void*) contextInfo
{
	if( returnCode == NSOKButton )
	{
		NSData* pdf = [[mDrawingView drawing] pdf];
		[pdf writeToURL:[panel URL] atomically:YES];
	}
}


#pragma mark -
#pragma mark - as the Window delegate

- (NSUndoManager*) windowWillReturnUndoManager:(NSWindow*) window
{
	// DK's own implementation of the undo manager is generally more functional than the default Cocoa one, especially
	// for interactive drawing as it implements task coalescing.
	
	static DKUndoManager* um = nil;
	
	if( um == nil )
		um = [[DKUndoManager alloc] init];

	return (NSUndoManager*)um;
}

@end
