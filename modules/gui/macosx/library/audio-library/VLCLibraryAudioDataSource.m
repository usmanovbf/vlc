/*****************************************************************************
 * VLCLibraryAudioDataSource.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan -dot- org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCLibraryAudioDataSource.h"

#import "main/VLCMain.h"

#import "library/VLCInputItem.h"
#import "library/VLCLibraryWindow.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibraryController.h"
#import "library/VLCLibraryDataTypes.h"
#import "library/VLCLibraryTableCellView.h"
#import "library/VLCLibraryTableView.h"
#import "library/VLCLibraryCollectionViewItem.h"
#import "library/VLCLibraryCollectionViewFlowLayout.h"
#import "library/VLCLibraryCollectionViewMediaItemSupplementaryDetailView.h"

#import "library/audio-library/VLCLibraryAlbumTableCellView.h"
#import "library/audio-library/VLCLibraryAudioGroupDataSource.h"
#import "library/audio-library/VLCLibraryCollectionViewAlbumSupplementaryDetailView.h"
#import "library/audio-library/VLCLibraryCollectionViewAudioGroupSupplementaryDetailView.h"
#import "library/audio-library/VLCLibrarySongsTableViewSongPlayingTableCellView.h"

#import "extensions/NSString+Helpers.h"
#import "extensions/NSPasteboardItem+VLCAdditions.h"

#import "playlist/VLCPlayerController.h"
#import "playlist/VLCPlaylistController.h"
#import "playlist/VLCPlaylistItem.h"
#import "playlist/VLCPlaylistModel.h"

#import "views/VLCImageView.h"
#import "views/VLCSubScrollView.h"

NSString * const VLCLibrarySongsTableViewSongPlayingColumnIdentifier = @"VLCLibrarySongsTableViewSongPlayingColumnIdentifier";
NSString * const VLCLibrarySongsTableViewTitleColumnIdentifier = @"VLCLibrarySongsTableViewTitleColumnIdentifier";
NSString * const VLCLibrarySongsTableViewDurationColumnIdentifier = @"VLCLibrarySongsTableViewDurationColumnIdentifier";
NSString * const VLCLibrarySongsTableViewArtistColumnIdentifier = @"VLCLibrarySongsTableViewArtistColumnIdentifier";
NSString * const VLCLibrarySongsTableViewAlbumColumnIdentifier = @"VLCLibrarySongsTableViewAlbumColumnIdentifier";
NSString * const VLCLibrarySongsTableViewGenreColumnIdentifier = @"VLCLibrarySongsTableViewGenreColumnIdentifier";
NSString * const VLCLibrarySongsTableViewPlayCountColumnIdentifier = @"VLCLibrarySongsTableViewPlayCountColumnIdentifier";
NSString * const VLCLibrarySongsTableViewYearColumnIdentifier = @"VLCLibrarySongsTableViewYearColumnIdentifier";

NSString * const VLCLibraryTitleSortDescriptorKey = @"VLCLibraryTitleSortDescriptorKey";
NSString * const VLCLibraryDurationSortDescriptorKey = @"VLCLibraryDurationSortDescriptorKey";
NSString * const VLCLibraryArtistSortDescriptorKey = @"VLCLibraryArtistSortDescriptorKey";
NSString * const VLCLibraryAlbumSortDescriptorKey = @"VLCLibraryAlbumSortDescriptorKey";
NSString * const VLCLibraryPlayCountSortDescriptorKey = @"VLCLibraryPlayCountSortDescriptorKey";
NSString * const VLCLibraryYearSortDescriptorKey = @"VLCLibraryYearSortDescriptorKey";
// TODO: Add sorting by genre

@interface VLCLibraryAudioDataSource ()
{
    enum vlc_ml_parent_type _currentParentType;

    id<VLCMediaLibraryItemProtocol> _selectedCollectionViewItem;
    id<VLCMediaLibraryItemProtocol> _selectedCollectionSelectionTableViewItem;
    id<VLCMediaLibraryItemProtocol> _selectedGroupSelectionTableViewItem;
    id<VLCMediaLibraryItemProtocol> _selectedSongTableViewItem;
}

@property (readwrite, atomic) NSArray *displayedCollection;

@end

@implementation VLCLibraryAudioDataSource

- (instancetype)init
{
    self = [super init];
    if(self) {
        NSNotificationCenter * const notificationCenter = NSNotificationCenter.defaultCenter;
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelAudioMediaItemsReset:)
                                   name:VLCLibraryModelAudioMediaListReset
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelAudioMediaItemUpdated:)
                                   name:VLCLibraryModelAudioMediaItemUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelAudioMediaItemDeleted:)
                                   name:VLCLibraryModelAudioMediaItemDeleted
                                 object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(libraryModelArtistsReset:)
                                   name:VLCLibraryModelArtistListUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelArtistUpdated:)
                                   name:VLCLibraryModelArtistUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelArtistDeleted:)
                                   name:VLCLibraryModelArtistDeleted
                                 object:nil];


        [notificationCenter addObserver:self
                               selector:@selector(libraryModelAlbumsReset:)
                                   name:VLCLibraryModelAlbumListUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelAlbumUpdated:)
                                   name:VLCLibraryModelAlbumUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelAlbumDeleted:)
                                   name:VLCLibraryModelAlbumDeleted
                                 object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(libraryModelGenresReset:)
                                   name:VLCLibraryModelGenreListUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelGenreUpdated:)
                                   name:VLCLibraryModelGenreUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelGenreDeleted:)
                                   name:VLCLibraryModelGenreDeleted
                                 object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(currentlyPlayingItemChanged:)
                                   name:VLCPlayerCurrentMediaItemChanged
                                 object:nil];
    }

    return self;
}

- (void)currentlyPlayingItemChanged:(NSNotification *)aNotification
{
    VLCPlayerController * const playerController = VLCMain.sharedInstance.playlistController.playerController;
    VLCInputItem * const currentInputItem = playerController.currentMedia;
    if (!currentInputItem) {
        return;
    }

    if (_currentParentType == VLC_ML_PARENT_UNKNOWN) {
        NSString * const currentItemMrl = currentInputItem.MRL;

        const NSUInteger itemIndexInDisplayedCollection = [self.displayedCollection indexOfObjectPassingTest:^BOOL(id element, NSUInteger idx, BOOL *stop) {
            VLCMediaLibraryMediaItem * const mediaItem = (VLCMediaLibraryMediaItem *)element;
            return [mediaItem.inputItem.MRL isEqualToString:currentItemMrl];
        }];

        if (itemIndexInDisplayedCollection != NSNotFound) {
            [_songsTableView scrollRowToVisible:itemIndexInDisplayedCollection];
        }
    }
}

- (NSArray *)collectionToDisplay
{
    switch(_currentParentType) {
        case VLC_ML_PARENT_UNKNOWN:
            return [_libraryModel listOfAudioMedia];
        case VLC_ML_PARENT_ALBUM:
            return [_libraryModel listOfAlbums];
        case VLC_ML_PARENT_ARTIST:
            return [_libraryModel listOfArtists];
        case VLC_ML_PARENT_GENRE:
            return [_libraryModel listOfGenres];
        default:
            return nil;
    }
}

- (void)libraryModelReset:(NSNotification * const)aNotification
{
    if(_libraryModel == nil) {
        return;
    }

    [self reloadData];
}

- (void)libraryModelAudioMediaItemsReset:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_UNKNOWN) {
        return;
    }

    [self libraryModelReset:aNotification];
}

- (void)libraryModelArtistsReset:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_ARTIST) {
        return;
    }

    [self libraryModelReset:aNotification];
}

- (void)libraryModelAlbumsReset:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_ALBUM) {
        return;
    }

    [self libraryModelReset:aNotification];
}

- (void)libraryModelGenresReset:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_GENRE) {
        return;
    }

    [self libraryModelReset:aNotification];
}

- (void)libraryModelAudioItemUpdated:(NSNotification * const)aNotification
{
    NSParameterAssert(aNotification);
    NSParameterAssert([aNotification.object conformsToProtocol:@protocol(VLCMediaLibraryItemProtocol)]);

    if(_libraryModel == nil) {
        return;
    }

    const id <VLCMediaLibraryItemProtocol> item = (id<VLCMediaLibraryItemProtocol>)aNotification.object;
    [self reloadDataForMediaLibraryItem:item];
}

- (void)libraryModelAudioMediaItemUpdated:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_UNKNOWN) {
        return;
    }

    [self libraryModelAudioItemUpdated:aNotification];
}

- (void)libraryModelArtistUpdated:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_ARTIST) {
        return;
    }

    [self libraryModelAudioItemUpdated:aNotification];
}

- (void)libraryModelAlbumUpdated:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_ALBUM) {
        return;
    }

    [self libraryModelAudioItemUpdated:aNotification];
}

- (void)libraryModelGenreUpdated:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_GENRE) {
        return;
    }

    [self libraryModelAudioItemUpdated:aNotification];
}

- (void)libraryModelAudioItemDeleted:(NSNotification * const)aNotification
{
    NSParameterAssert(aNotification);
    NSParameterAssert([aNotification.object conformsToProtocol:@protocol(VLCMediaLibraryItemProtocol)]);

    if(_libraryModel == nil) {
        return;
    }

    const id <VLCMediaLibraryItemProtocol> item = (id<VLCMediaLibraryItemProtocol>)aNotification.object;
    [self deleteDataForMediaLibraryItem:item];
}

- (void)libraryModelAudioMediaItemDeleted:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_UNKNOWN) {
        return;
    }

    [self libraryModelAudioItemDeleted:aNotification];
}

- (void)libraryModelArtistDeleted:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_ARTIST) {
        return;
    }

    [self libraryModelAudioItemDeleted:aNotification];
}

- (void)libraryModelAlbumDeleted:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_ALBUM) {
        return;
    }

    [self libraryModelAudioItemDeleted:aNotification];
}

- (void)libraryModelGenreDeleted:(NSNotification * const)aNotification
{
    if (_currentParentType != VLC_ML_PARENT_GENRE) {
        return;
    }

    [self libraryModelAudioMediaItemDeleted:aNotification];
}

- (void)retainSelectedMediaItem
{
    if(_collectionView.selectionIndexPaths.count > 0 && !_collectionView.hidden) {
        _selectedCollectionViewItem = [self selectedCollectionViewItem];
    }

    const NSInteger collectionSelectionTableViewRow = _collectionSelectionTableView.selectedRow;
    if(collectionSelectionTableViewRow >= 0 && !_collectionSelectionTableView.hidden) {
        _selectedCollectionSelectionTableViewItem = [self libraryItemAtRow:collectionSelectionTableViewRow
                                                              forTableView:_collectionSelectionTableView];
    }

    const NSInteger groupSelectionTableViewRow = _groupSelectionTableView.selectedRow;
    if(groupSelectionTableViewRow >= 0 && !_groupSelectionTableView.hidden) {
        _selectedGroupSelectionTableViewItem = [self libraryItemAtRow:groupSelectionTableViewRow
                                                         forTableView:_groupSelectionTableView];
    }

    const NSInteger songsTableViewRow = _songsTableView.selectedRow;
    if(songsTableViewRow >= 0 && !_songsTableView.hidden) {
        _selectedSongTableViewItem = [self libraryItemAtRow:songsTableViewRow
                                               forTableView:_songsTableView];
    }
}

- (id<VLCMediaLibraryItemProtocol>)selectedCollectionViewItem
{
    NSIndexPath *indexPath = _collectionView.selectionIndexPaths.anyObject;
    if (!indexPath) {
        return nil;
    }

    return self.displayedCollection[indexPath.item];
}

- (void)restoreSelectionState
{
    [self restoreCollectionViewSelectionState];
    [self restoreCollectionSelectionTableViewSelectionState];
    [self restoreGroupSelectionTableViewSelectionState];
    [self restoreSongTableViewSelectionState];
}

- (NSUInteger)findSelectedItemNewIndex:(id<VLCMediaLibraryItemProtocol>)item
{
    return [self.displayedCollection indexOfObjectPassingTest:^BOOL(id element, NSUInteger idx, BOOL *stop) {
        id<VLCMediaLibraryItemProtocol> itemElement = (id<VLCMediaLibraryItemProtocol>)element;
        return itemElement.libraryID == item.libraryID;
    }];
}

- (void)restoreCollectionViewSelectionState
{
    if (!_selectedCollectionViewItem) {
        return;
    }

    const NSUInteger newIndexOfSelectedItem = [self findSelectedItemNewIndex:_selectedCollectionViewItem];
    if(newIndexOfSelectedItem == NSNotFound) {
        return;
    }

    NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:newIndexOfSelectedItem inSection:0];
    NSSet *indexPathSet = [NSSet setWithObject:newIndexPath];
    [_collectionView selectItemsAtIndexPaths:indexPathSet scrollPosition:NSCollectionViewScrollPositionTop];
    // selectItemsAtIndexPaths does not call any delegate methods so we do it manually
    [_collectionView.delegate collectionView:_collectionView didSelectItemsAtIndexPaths:indexPathSet];
    _selectedCollectionViewItem = nil;
}

- (void)restoreSelectionStateForTableView:(NSTableView*)tableView
                         withSelectedItem:(id<VLCMediaLibraryItemProtocol>)item
{
    const NSUInteger newIndexOfSelectedItem = [self findSelectedItemNewIndex:item];
    if(newIndexOfSelectedItem == NSNotFound || newIndexOfSelectedItem < 0) {
        return;
    }

    NSIndexSet *newSelectedRowIndexSet = [NSIndexSet indexSetWithIndex:newIndexOfSelectedItem];
    [tableView selectRowIndexes:newSelectedRowIndexSet byExtendingSelection:NO];
}

- (void)restoreCollectionSelectionTableViewSelectionState
{
    [self restoreSelectionStateForTableView:_collectionSelectionTableView
                           withSelectedItem:_selectedCollectionSelectionTableViewItem];
    _selectedCollectionSelectionTableViewItem = nil;
}

- (void)restoreGroupSelectionTableViewSelectionState
{
    [self restoreSelectionStateForTableView:_groupSelectionTableView
                           withSelectedItem:_selectedGroupSelectionTableViewItem];
    _selectedGroupSelectionTableViewItem = nil;
}

- (void)restoreSongTableViewSelectionState
{
    [self restoreSelectionStateForTableView:_songsTableView
                           withSelectedItem:_selectedSongTableViewItem];
    _selectedSongTableViewItem = nil;
}

- (void)setup
{
    [self setupCollectionView:_collectionView];
    [self setupCollectionView:_gridModeListSelectionCollectionView];
    [self setupTableViews];

    _audioLibrarySegment = -1; // Force setAudioLibrarySegment to do something always on first try
}

- (void)setupCollectionView:(NSCollectionView *)collectionView
{
    [collectionView registerClass:[VLCLibraryCollectionViewItem class] forItemWithIdentifier:VLCLibraryCellIdentifier];

    NSNib *albumSupplementaryDetailView = [[NSNib alloc] initWithNibNamed:@"VLCLibraryCollectionViewAlbumSupplementaryDetailView" bundle:nil];
    [collectionView registerNib:albumSupplementaryDetailView
      forSupplementaryViewOfKind:VLCLibraryCollectionViewAlbumSupplementaryDetailViewKind
                  withIdentifier:VLCLibraryCollectionViewAlbumSupplementaryDetailViewIdentifier];

    NSNib *audioGroupSupplementaryDetailView = [[NSNib alloc] initWithNibNamed:@"VLCLibraryCollectionViewAudioGroupSupplementaryDetailView" bundle:nil];
    [collectionView registerNib:audioGroupSupplementaryDetailView
      forSupplementaryViewOfKind:VLCLibraryCollectionViewAudioGroupSupplementaryDetailViewKind
                  withIdentifier:VLCLibraryCollectionViewAudioGroupSupplementaryDetailViewIdentifier];

    NSNib *mediaItemSupplementaryDetailView = [[NSNib alloc] initWithNibNamed:@"VLCLibraryCollectionViewMediaItemSupplementaryDetailView" bundle:nil];
    [collectionView registerNib:mediaItemSupplementaryDetailView
      forSupplementaryViewOfKind:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewKind
                  withIdentifier:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewIdentifier];
}

- (void)setupTableViews
{
    _groupSelectionTableView.target = self;
    _groupSelectionTableView.doubleAction = @selector(groubSelectionDoubleClickAction:);

    _collectionSelectionTableView.target = self;
    _collectionSelectionTableView.doubleAction = @selector(collectionSelectionDoubleClickAction:);

    _gridModeListTableView.target = self;
    _gridModeListTableView.doubleAction = @selector(groubSelectionDoubleClickAction:);

    [self setupSongsTableView];
}

- (void)setupSongsTableView
{
    _songsTableView.target = self;
    _songsTableView.doubleAction = @selector(songDoubleClickAction:);

    [self setupPrototypeSortDescriptorsForTableView:_songsTableView];
    [self setupExistingSortForTableView:_songsTableView];
}

- (void)setupPrototypeSortDescriptorsForTableView:(NSTableView *)tableView
{
    for(NSTableColumn *column in tableView.tableColumns) {
        NSSortDescriptor * const columnSortDescriptor = [self sortDescriptorPrototypeForSongsTableViewColumnIdentifier:column.identifier];

        if(columnSortDescriptor) {
            column.sortDescriptorPrototype = columnSortDescriptor;
        }
    }
}

- (NSSortDescriptor *)sortDescriptorPrototypeForSongsTableViewColumnIdentifier:(NSString *)columnIdentifier
{
    if ([columnIdentifier isEqualToString:VLCLibrarySongsTableViewTitleColumnIdentifier]) {
        return [[NSSortDescriptor alloc] initWithKey:VLCLibraryTitleSortDescriptorKey ascending:true];

    } else if ([columnIdentifier isEqualToString:VLCLibrarySongsTableViewDurationColumnIdentifier]) {
        return [[NSSortDescriptor alloc] initWithKey:VLCLibraryDurationSortDescriptorKey ascending:true];

    } else if ([columnIdentifier isEqualToString:VLCLibrarySongsTableViewArtistColumnIdentifier]) {
        return [[NSSortDescriptor alloc] initWithKey:VLCLibraryArtistSortDescriptorKey ascending:true];

    } else if ([columnIdentifier isEqualToString:VLCLibrarySongsTableViewAlbumColumnIdentifier]) {
        return [[NSSortDescriptor alloc] initWithKey:VLCLibraryAlbumSortDescriptorKey ascending:true];

    } else if ([columnIdentifier isEqualToString:VLCLibrarySongsTableViewPlayCountColumnIdentifier]) {
        return [[NSSortDescriptor alloc] initWithKey:VLCLibraryPlayCountSortDescriptorKey ascending:true];

    } else if ([columnIdentifier isEqualToString:VLCLibrarySongsTableViewYearColumnIdentifier]) {
        return [[NSSortDescriptor alloc] initWithKey:VLCLibraryYearSortDescriptorKey ascending:true];

    }

    return nil;
}

- (void)setupExistingSortForTableView:(NSTableView *)tableView
{
    const VLCLibraryController * const libraryController = VLCMain.sharedInstance.libraryController;
    const vlc_ml_sorting_criteria_t existingSortCriteria = libraryController.lastSortingCriteria;

    NSString *sortDescriptorKey = [self sortDescriptorKeyFromVlcMlSortingCriteria:existingSortCriteria];
    const NSSortDescriptor * const sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortDescriptorKey
                                                                                ascending:!libraryController.descendingLibrarySorting];

    tableView.sortDescriptors = @[sortDescriptor];
}

- (NSString *)sortDescriptorKeyFromVlcMlSortingCriteria:(vlc_ml_sorting_criteria_t)existingSortCriteria
{
    if (existingSortCriteria == VLC_ML_SORTING_DEFAULT) {
        return VLCLibraryTitleSortDescriptorKey;

    } else if (existingSortCriteria == VLC_ML_SORTING_DURATION) {
        return VLCLibraryDurationSortDescriptorKey;

    } else if (existingSortCriteria == VLC_ML_SORTING_ARTIST) {
        return VLCLibraryArtistSortDescriptorKey;

    } else if (existingSortCriteria == VLC_ML_SORTING_ALBUM) {
        return VLCLibraryAlbumSortDescriptorKey;

    } else if (existingSortCriteria == VLC_ML_SORTING_PLAYCOUNT) {
        return VLCLibraryPlayCountSortDescriptorKey;

    } else if (existingSortCriteria == VLC_ML_SORTING_RELEASEDATE) {
        return VLCLibraryYearSortDescriptorKey;

    }

    return VLCLibraryTitleSortDescriptorKey;
}

- (void)resetLayoutsForOperation:(void(^)(void))operation
{
    VLCLibraryCollectionViewFlowLayout *collectionViewFlowLayout = (VLCLibraryCollectionViewFlowLayout *)_collectionView.collectionViewLayout;
    if (collectionViewFlowLayout) {
        [collectionViewFlowLayout resetLayout];
    }

    VLCLibraryCollectionViewFlowLayout *gridModeListSelectionCollectionViewFlowLayout = (VLCLibraryCollectionViewFlowLayout *)_gridModeListSelectionCollectionView.collectionViewLayout;
    if (gridModeListSelectionCollectionViewFlowLayout) {
        [gridModeListSelectionCollectionViewFlowLayout resetLayout];
    }

    operation();
    [self setupExistingSortForTableView:_songsTableView];
}

- (void)reloadData
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self retainSelectedMediaItem];
        self.displayedCollection = [self collectionToDisplay];

        [self resetLayoutsForOperation:^{
            [self.collectionView reloadData];
            [self.gridModeListTableView reloadData];
            [self.gridModeListSelectionCollectionView reloadData];
            [self.collectionSelectionTableView reloadData];
            [self.groupSelectionTableView reloadData];
            [self.songsTableView reloadData];
        }];
        [self restoreSelectionState];
    });
}

- (NSUInteger)indexForMediaLibraryItemWithId:(const int64_t)itemId
{
    return [self.displayedCollection indexOfObjectPassingTest:^BOOL(const id<VLCMediaLibraryItemProtocol> item, const NSUInteger idx, BOOL * const stop) {
        NSAssert(item != nil, @"Cache list should not contain nil items");
        return item.libraryID == itemId;
    }];
}

- (void)reloadDataForMediaLibraryItem:(const id<VLCMediaLibraryItemProtocol>)item
{
    [self resetLayoutsForOperation:^{
        const NSUInteger index = [self indexForMediaLibraryItemWithId:item.libraryID];
        if (index == NSNotFound) {
            return;
        }

        NSMutableArray * const mutableCollectionCopy = [self.displayedCollection mutableCopy];
        [mutableCollectionCopy replaceObjectAtIndex:index withObject:item];
        self.displayedCollection = [mutableCollectionCopy copy];

        NSIndexPath * const indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        NSIndexSet * const rowIndexSet = [NSIndexSet indexSetWithIndex:index];

        NSRange songsTableColumnRange = NSMakeRange(0, self->_songsTableView.numberOfColumns);
        NSIndexSet * const songsTableColumnIndexSet = [NSIndexSet indexSetWithIndexesInRange:songsTableColumnRange];

        [self.collectionView reloadItemsAtIndexPaths:[NSSet setWithObject:indexPath]];
        [self.songsTableView reloadDataForRowIndexes:rowIndexSet columnIndexes:songsTableColumnIndexSet];

        // Don't update gridModeListSelectionCollectionView, let its VLCLibraryAudioGroupDataSource do it.
        // TODO: Stop splitting functionality for these audio source selection views between this data source
        // TODO: and the VLCLibraryAudioGroupDataSource, it is super confusing

        // Also don't update:
        // - gridModeListTableView, as this will only show artists/genres
        // - collectionSelectionTableView, as this will only show artists/genres/albums
        // - groupSelectionTableView, as this shows cells for albums (and each cell has its own data source with media items)
    }];
}

- (void)deleteDataForMediaLibraryItem:(const id<VLCMediaLibraryItemProtocol>)item
{
    [self resetLayoutsForOperation:^{
        const NSUInteger index = [self indexForMediaLibraryItemWithId:item.libraryID];
        if (index == NSNotFound) {
            return;
        }

        NSMutableArray * const mutableCollectionCopy = [self.displayedCollection mutableCopy];
        [mutableCollectionCopy removeObjectAtIndex:index];
        self.displayedCollection = [mutableCollectionCopy copy];

        NSIndexPath * const indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        NSIndexSet * const rowIndexSet = [NSIndexSet indexSetWithIndex:index];

        [self.collectionView deleteItemsAtIndexPaths:[NSSet setWithObject:indexPath]];
        [self.songsTableView removeRowsAtIndexes:rowIndexSet withAnimation:NSTableViewAnimationSlideUp];

        // Comment in reloadDataForMediaLibraryItem will be informative
    }];
}

- (void)setAudioLibrarySegment:(VLCAudioLibrarySegment)audioLibrarySegment
{
    if (audioLibrarySegment == _audioLibrarySegment) {
        return;
    }

    _audioLibrarySegment = audioLibrarySegment;
    switch (_audioLibrarySegment) {
        case VLCAudioLibraryArtistsSegment:
            self.displayedCollection = [self.libraryModel listOfArtists];
            _currentParentType = VLC_ML_PARENT_ARTIST;
            break;
        case VLCAudioLibraryAlbumsSegment:
            self.displayedCollection = [self.libraryModel listOfAlbums];
            _currentParentType = VLC_ML_PARENT_ALBUM;
            break;
        case VLCAudioLibrarySongsSegment:
            self.displayedCollection = [self.libraryModel listOfAudioMedia];
            _currentParentType = VLC_ML_PARENT_UNKNOWN;
            break;
        case VLCAudioLibraryGenresSegment:
            self.displayedCollection = [self.libraryModel listOfGenres];
            _currentParentType = VLC_ML_PARENT_GENRE;
            break;

        default:
            NSAssert(1, @"reached the unreachable");
            break;
    }

    _audioGroupDataSource.representedListOfAlbums = nil; // Clear whatever was being shown before
    [self reloadData];
}

#pragma mark - table view data source and delegation

- (BOOL)displayAllArtistsGenresTableEntry
{
    return _currentParentType == VLC_ML_PARENT_GENRE ||
           _currentParentType == VLC_ML_PARENT_ARTIST;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    const NSInteger numItems = self.displayedCollection.count;
    return [self displayAllArtistsGenresTableEntry] ? numItems + 1 : numItems;
}

- (id<VLCMediaLibraryItemProtocol>)libraryItemAtRow:(NSInteger)row
                                       forTableView:(NSTableView *)tableView
{
    BOOL viewDisplayingAllItemsEntry = [self displayAllArtistsGenresTableEntry];
    BOOL provideAllItemsEntry = viewDisplayingAllItemsEntry && row == 0;

    if (provideAllItemsEntry && _currentParentType == VLC_ML_PARENT_GENRE) {
        return [[VLCMediaLibraryDummyItem alloc] initWithDisplayString:_NS("All genres")
                                                      withDetailString:@""];
    } else if (provideAllItemsEntry && _currentParentType == VLC_ML_PARENT_ARTIST) {
        return [[VLCMediaLibraryDummyItem alloc] initWithDisplayString:_NS("All artists")
                                                      withDetailString:@""];
    } else if (viewDisplayingAllItemsEntry) {
        return self.displayedCollection[row - 1];
    }

    return self.displayedCollection[row];
}

- (void)tableView:(NSTableView * const)tableView selectRow:(NSInteger)row
{
    NSParameterAssert(tableView);
    
    if (tableView != _collectionSelectionTableView && tableView != _groupSelectionTableView && tableView != _gridModeListTableView) {
        return;
    }

    if (tableView.selectedRow != row) {
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }

    const NSInteger selectedRow = tableView.selectedRow;
    const BOOL showingAllItemsEntry = [self displayAllArtistsGenresTableEntry];
    const NSInteger libraryItemIndex = showingAllItemsEntry ? selectedRow - 1 : selectedRow;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        if (libraryItemIndex < 0 && showingAllItemsEntry) {
            self->_audioGroupDataSource.representedListOfAlbums = self->_libraryModel.listOfAlbums;
        } else {
            id<VLCMediaLibraryItemProtocol> libraryItem = self.displayedCollection[libraryItemIndex];

            if (self->_currentParentType == VLC_ML_PARENT_ALBUM) {
                self->_audioGroupDataSource.representedListOfAlbums = @[(VLCMediaLibraryAlbum *)libraryItem];
            } else if(self->_currentParentType != VLC_ML_PARENT_UNKNOWN) {
                self->_audioGroupDataSource.representedListOfAlbums = [self->_libraryModel listAlbumsOfParentType:self->_currentParentType forID:libraryItem.libraryID];
            } else { // FIXME: we have nothing to show here
                self->_audioGroupDataSource.representedListOfAlbums = nil;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.groupSelectionTableView reloadData];
            [self.gridModeListSelectionCollectionView reloadData];
        });
    });
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors
{
    const NSSortDescriptor * const sortDescriptor = tableView.sortDescriptors.firstObject;
    const vlc_ml_sorting_criteria_t sortCriteria = [self sortDescriptorKeyToVlcMlSortingCriteria:sortDescriptor.key];

    [VLCMain.sharedInstance.libraryController sortByCriteria:sortCriteria andDescending:!sortDescriptor.ascending];
    [self reloadData];
}

- (vlc_ml_sorting_criteria_t)sortDescriptorKeyToVlcMlSortingCriteria:(NSString *)sortDescriptorKey
{
    if ([sortDescriptorKey isEqualToString:VLCLibraryTitleSortDescriptorKey]) {
        return VLC_ML_SORTING_DEFAULT;

    } else if ([sortDescriptorKey isEqualToString:VLCLibraryDurationSortDescriptorKey]) {
        return VLC_ML_SORTING_DURATION;

    } else if ([sortDescriptorKey isEqualToString:VLCLibraryArtistSortDescriptorKey]) {
        return VLC_ML_SORTING_ARTIST;

    } else if ([sortDescriptorKey isEqualToString:VLCLibraryAlbumSortDescriptorKey]) {
        return VLC_ML_SORTING_ALBUM;

    } else if ([sortDescriptorKey isEqualToString:VLCLibraryPlayCountSortDescriptorKey]) {
        return VLC_ML_SORTING_PLAYCOUNT;

    } else if ([sortDescriptorKey isEqualToString:VLCLibraryYearSortDescriptorKey]) {
        return VLC_ML_SORTING_RELEASEDATE;

    }

    return VLC_ML_SORTING_DEFAULT;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row
{
    const id<VLCMediaLibraryItemProtocol> libraryItem = [self libraryItemAtRow:row forTableView:tableView];

    return [NSPasteboardItem pasteboardItemWithLibraryItem:libraryItem];
}

#pragma mark - table view double click actions

- (void)groubSelectionDoubleClickAction:(id)sender
{
    NSArray *listOfAlbums = _audioGroupDataSource.representedListOfAlbums;
    NSUInteger albumCount = listOfAlbums.count;
    NSInteger clickedRow = _groupSelectionTableView.clickedRow;

    if (!listOfAlbums || albumCount == 0 || clickedRow > albumCount) {
        return;
    }

    NSArray * const tracks = [listOfAlbums[clickedRow] tracksAsMediaItems];
    [VLCMain.sharedInstance.libraryController appendItemsToPlaylist:tracks playFirstItemImmediately:YES];
}

- (void)collectionSelectionDoubleClickAction:(id)sender
{
    id<VLCMediaLibraryItemProtocol> libraryItem = self.displayedCollection[self.collectionSelectionTableView.selectedRow];
    
    [libraryItem iterateMediaItemsWithBlock:^(VLCMediaLibraryMediaItem* mediaItem) {
        [VLCMain.sharedInstance.libraryController appendItemToPlaylist:mediaItem playImmediately:YES];
    }];
}

- (void)songDoubleClickAction:(id)sender
{
    NSAssert(_audioLibrarySegment == VLCAudioLibrarySongsSegment, @"Should not be possible to trigger this action from a non-song library view");
    VLCMediaLibraryMediaItem *mediaItem = self.displayedCollection[_songsTableView.selectedRow];
    [VLCMain.sharedInstance.libraryController appendItemToPlaylist:mediaItem playImmediately:YES];
}

#pragma mark - collection view data source

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.displayedCollection.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView
{
    return 1;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    VLCLibraryCollectionViewItem *viewItem = [collectionView makeItemWithIdentifier:VLCLibraryCellIdentifier forIndexPath:indexPath];
    viewItem.representedItem = self.displayedCollection[indexPath.item];
    return viewItem;
}

- (NSView *)collectionView:(NSCollectionView *)collectionView
viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind
               atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:VLCLibraryCollectionViewAlbumSupplementaryDetailViewKind]) {

        VLCLibraryCollectionViewAlbumSupplementaryDetailView* albumSupplementaryDetailView = [collectionView makeSupplementaryViewOfKind:kind withIdentifier:VLCLibraryCollectionViewAlbumSupplementaryDetailViewKind forIndexPath:indexPath];

        VLCMediaLibraryAlbum * const album = self.displayedCollection[indexPath.item];
        albumSupplementaryDetailView.representedAlbum = album;
        albumSupplementaryDetailView.selectedItem = [collectionView itemAtIndex:indexPath.item];
        albumSupplementaryDetailView.parentScrollView = VLCMain.sharedInstance.libraryWindow.audioCollectionViewScrollView;
        albumSupplementaryDetailView.internalScrollView.scrollParentY = YES;

        return albumSupplementaryDetailView;

    } else if ([kind isEqualToString:VLCLibraryCollectionViewAudioGroupSupplementaryDetailViewKind]) {

        VLCLibraryCollectionViewAudioGroupSupplementaryDetailView* audioGroupSupplementaryDetailView = [collectionView makeSupplementaryViewOfKind:kind withIdentifier:VLCLibraryCollectionViewAudioGroupSupplementaryDetailViewKind forIndexPath:indexPath];

        id<VLCMediaLibraryAudioGroupProtocol> audioGroup = self.displayedCollection[indexPath.item];
        audioGroupSupplementaryDetailView.representedAudioGroup = audioGroup;
        audioGroupSupplementaryDetailView.selectedItem = [collectionView itemAtIndex:indexPath.item];
        audioGroupSupplementaryDetailView.parentScrollView = VLCMain.sharedInstance.libraryWindow.audioCollectionViewScrollView;
        audioGroupSupplementaryDetailView.internalScrollView.scrollParentY = YES;

        return audioGroupSupplementaryDetailView;

    } else if ([kind isEqualToString:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewKind]) {

        VLCLibraryCollectionViewMediaItemSupplementaryDetailView* mediaItemSupplementaryDetailView = [collectionView makeSupplementaryViewOfKind:kind withIdentifier:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewKind forIndexPath:indexPath];

        VLCMediaLibraryMediaItem * const mediaItem = self.displayedCollection[indexPath.item];
        mediaItemSupplementaryDetailView.representedMediaItem = mediaItem;
        mediaItemSupplementaryDetailView.selectedItem = [collectionView itemAtIndex:indexPath.item];

        return mediaItemSupplementaryDetailView;
    }

    return nil;
}

- (id<VLCMediaLibraryItemProtocol>)libraryItemAtIndexPath:(NSIndexPath *)indexPath
                                        forCollectionView:(NSCollectionView *)collectionView
{
    return self.displayedCollection[indexPath.item];
}

@end
