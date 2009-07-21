#import "Three20/TTModelViewController.h"

///////////////////////////////////////////////////////////////////////////////////////////////////

@interface TTDefaultModel : TTModel
@end

@implementation TTDefaultModel

- (BOOL)isLoaded {
  return YES;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTModelViewController

@synthesize model = _model, modelError = _modelError;

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

- (void)resetViewStates {
  if (_flags.isShowingLoading) {
    [self showLoading:NO];
    _flags.isShowingLoading = NO;
  }
  if (_flags.isShowingModel) {
    [self showModel:NO];
    _flags.isShowingModel = NO;
  }
  if (_flags.isShowingError) {
    [self showError:NO];
    _flags.isShowingError = NO;
  }
  if (_flags.isShowingEmpty) {
    [self showEmpty:NO];
    _flags.isShowingEmpty = NO;
  }
}

- (void)updateViewStates {
  if (_flags.isModelWillLoadInvalid) {
    [self willLoadModel];
    _flags.isModelWillLoadInvalid = NO;
  }
  if (_flags.isModelDidLoadInvalid) {
    [self didLoadModel];
    _flags.isModelDidLoadInvalid = NO;
    _flags.isShowingModel = NO;
  }
  
  BOOL showModel = NO, showLoading = NO, showError = NO, showEmpty = NO;
  
  if (_model.isLoaded || ![self shouldLoad]) {
    if ([self canShowModel]) {
      showModel = !_flags.isShowingModel;
      _flags.isShowingModel = YES;
    } else {
      if (_flags.isShowingModel) {
        [self showModel:NO];
        _flags.isShowingModel = NO;
      }
    }
  } else {
    if (_flags.isShowingModel) {
      [self showModel:NO];
      _flags.isShowingModel = NO;
    }
  }

  if (_model.isLoading) {
    showLoading = !_flags.isShowingLoading;
    _flags.isShowingLoading = YES;
  } else {
    if (_flags.isShowingLoading) {
      [self showLoading:NO];
      _flags.isShowingLoading = NO;
    }
  }

  if (_modelError) {
    showError = !_flags.isShowingError;
    _flags.isShowingError = YES;
  } else {
    if (_flags.isShowingError) {
      [self showError:NO];
      _flags.isShowingError = NO;
    }
  }

  if (!_flags.isShowingLoading && !_flags.isShowingModel && !_flags.isShowingError) {
    showEmpty = !_flags.isShowingEmpty;
    _flags.isShowingEmpty = YES;
  } else {
    if (_flags.isShowingEmpty) {
      [self showEmpty:NO];
      _flags.isShowingEmpty = NO;
    }
  }
  
  if (showModel) {
    [self showModel:YES];
    [self didShowModel];
  }
  if (showEmpty) {
    [self showEmpty:YES];
  }
  if (showError) {
    [self showError:YES];
  }
  if (showLoading) {
    [self showLoading:YES];
  }
}

- (void)updateView {
  if (_flags.isViewInvalid && !_flags.isViewSuspended && !_flags.isUpdatingView) {
    _flags.isUpdatingView = YES;

    // Ensure the model is created
    self.model;
    // Ensure the view is created
    self.view;

    [self updateViewStates];

    if (_frozenState && _flags.isShowingModel) {
      [self restoreView:_frozenState];
      TT_RELEASE_SAFELY(_frozenState);
    }

    _flags.isViewInvalid = NO;
    _flags.isUpdatingView = NO;
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)init {
  if (self = [super init]) {
    _model = nil;
    _modelError = nil;
    _flags.isModelDidLoadInvalid = NO;
    _flags.isModelWillLoadInvalid = NO;
    _flags.isViewInvalid = YES;
    _flags.isViewSuspended = NO;
    _flags.isUpdatingView = NO;
    _flags.isShowingEmpty = NO;
    _flags.isShowingLoading = NO;
    _flags.isShowingModel = NO;
    _flags.isShowingError = NO;
  }
  return self;
}

- (void)dealloc {
  [_model.delegates removeObject:self];
  TT_RELEASE_SAFELY(_model);
  TT_RELEASE_SAFELY(_modelError);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UIViewController

- (void)viewWillAppear:(BOOL)animated {
  _isViewAppearing = YES;
  _hasViewAppeared = YES;
  
  [self updateView];
  [self reloadIfNeeded];
  
  [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
  if (_hasViewAppeared && !_isViewAppearing) {
    [super didReceiveMemoryWarning];
    [self invalidateView];
  } else {
    [super didReceiveMemoryWarning];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTModelDelegate

- (void)modelDidStartLoad:(id<TTModel>)model {
  if (model == self.model) {
    [self invalidateView];
  }
}

- (void)modelDidFinishLoad:(id<TTModel>)model {
  if (model == _model) {
    TT_RELEASE_SAFELY(_modelError);
    _flags.isModelDidLoadInvalid = YES;
    [self invalidateView];
  }
}

- (void)model:(id<TTModel>)model didFailLoadWithError:(NSError*)error {
  if (model == _model) {
    self.modelError = error;
  }
}

- (void)modelDidCancelLoad:(id<TTModel>)model {
  if (model == _model) {
    [self invalidateView];
  }
}

- (void)modelDidChange:(id<TTModel>)model {
  if (model == _model) {
    [self refresh];
  }
}

- (void)modelDidBeginUpdate:(id<TTModel>)model {
  if (model == _model) {
    _flags.isViewSuspended = YES;
  }
}

- (void)modelDidEndUpdate:(id<TTModel>)model {
  if (model == _model) {
    _flags.isViewSuspended = NO;
    [self updateView];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// public

- (id<TTModel>)model {
  if (!_model) {
    [self createModel];
    if (!_model) {
      self.model = [[[TTDefaultModel alloc] init] autorelease];
    }
  }
  return _model;
}

- (void)setModel:(id<TTModel>)model {
  if (_model != model) {
    [_model.delegates removeObject:self];
    [_model release];
    _model = [model retain];
    [_model.delegates addObject:self];
    
    if (_model) {
      _flags.isModelWillLoadInvalid = YES;
    }
    
    [self refresh];
  }
}

- (void)setModelError:(NSError*)error {
  if (error != _modelError) {
    [_modelError release];
    _modelError = [error retain];

    [self invalidateView];
  }
}

- (void)createModel {
}

- (BOOL)isModelCreated {
  return !!_model;
}

- (BOOL)shouldLoad {
  return !self.model.isLoaded;
}

- (BOOL)shouldReload {
  return !_modelError && self.model.isOutdated;
}

- (BOOL)shouldLoadMore {
  return NO;
}

- (BOOL)canShowModel {
  return YES;
}

- (void)reload {
  _flags.isViewInvalid = YES;
  [self.model load:TTURLRequestCachePolicyNetwork more:NO];
}

- (void)reloadIfNeeded {
  if ([self shouldReload]) {
    [self reload];
  }
}

- (void)refresh {
  _flags.isViewInvalid = YES;
  _flags.isModelWillLoadInvalid = YES;

  BOOL tryToLoad = !self.model.isLoading && !self.model.isLoaded;
  if (tryToLoad && [self shouldLoad]) {
    [self.model load:TTURLRequestCachePolicyDefault more:NO];
  } else if (tryToLoad && [self shouldReload]) {
    [self.model load:TTURLRequestCachePolicyNetwork more:NO];
  } else if (tryToLoad && [self shouldLoadMore]) {
    [self.model load:TTURLRequestCachePolicyDefault more:YES];
  } else {
    _flags.isModelDidLoadInvalid = YES;
    if (_isViewAppearing) {
      [self updateView];
    }
  }
}

- (void)invalidateView {
  _flags.isViewInvalid = YES;
  if (_isViewAppearing) {
    [self updateView];
  }
}

- (void)validateView {
  _flags.isViewInvalid = YES;
  [self updateView];
}

- (void)willLoadModel {
}

- (void)didLoadModel {
}

- (void)didShowModel {
}

- (void)showLoading:(BOOL)show {
}

- (void)showModel:(BOOL)show {
}

- (void)showEmpty:(BOOL)show {
}

- (void)showError:(BOOL)show {
}

@end