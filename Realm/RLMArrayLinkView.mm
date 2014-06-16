////////////////////////////////////////////////////////////////////////////
//
// TIGHTDB CONFIDENTIAL
// __________________
//
//  [2011] - [2014] TightDB Inc
//  All Rights Reserved.
//
// NOTICE:  All information contained herein is, and remains
// the property of TightDB Incorporated and its suppliers,
// if any.  The intellectual and technical concepts contained
// herein are proprietary to TightDB Incorporated
// and its suppliers and may be covered by U.S. and Foreign Patents,
// patents in process, and are protected by trade secret or copyright law.
// Dissemination of this information or reproduction of this material
// is strictly forbidden unless prior written permission is obtained
// from TightDB Incorporated.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMArray_Private.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMObject_Private.h"
#import "RLMSchema.h"
#import "RLMObjectStore.h"
#import "RLMQueryUtil.h"
#import "RLMConstants.h"

#import <objc/runtime.h>

//
// RLMArray implementation
//
@implementation RLMArrayLinkView {
    tightdb::util::UniquePtr<tightdb::Query> _backingQuery;
}

+ (RLMArrayLinkView *)arrayWithObjectClassName:(NSString *)objectClassName
                                          view:(tightdb::LinkViewRef)view
                                         realm:(RLMRealm *)realm {
    RLMArrayLinkView *ar = [[RLMArrayLinkView alloc] initWithObjectClassName:objectClassName];
    ar->_backingLinkView = view;
    ar->_realm = realm;
    [realm registerAccessor:ar];
    
    // make readonly if not in write transaction
    if (realm.transactionMode != RLMTransactionModeWrite) {
        object_setClass(ar, RLMArrayLinkViewReadOnly.class);
    }
    return ar;
}

- (void)setWritable:(BOOL)writable {
    if (writable) {
        object_setClass(self, RLMArrayLinkView.class);
    }
    else {
        object_setClass(self, RLMArrayLinkViewReadOnly.class);
    }
    _writable = writable;
}

- (NSUInteger)count {
    return _backingLinkView->size();
}

inline id RLMCreateAccessorForArrayIndex(RLMArrayLinkView *array, NSUInteger index) {
    return RLMCreateObjectAccessor(array.realm,
                                   array.objectClassName,
                                   array->_backingLinkView->get_target_row(index));
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len {
    NSUInteger batchCount = 0, index = state->state, count = self.count;
    
    __autoreleasing id *autoreleasingBuffer = (__autoreleasing id *)(void *)buffer;
    while (index < count && batchCount < len) {
        autoreleasingBuffer[batchCount++] = RLMCreateAccessorForArrayIndex(self, index++);
    }
    
    state->mutationsPtr = state->extra;
    state->itemsPtr = buffer;
    state->state = index;
    return batchCount;
}

- (id)objectAtIndex:(NSUInteger)index {
    if (index >= self.count) {
        @throw [NSException exceptionWithName:@"RLMException" reason:@"Index is out of bounds." userInfo:@{@"index": @(index)}];
    }
    return RLMCreateAccessorForArrayIndex(self, index);;
}

inline void RLMValidateObjectClass(RLMObject *obj, NSString *expected) {
    NSString *objectClassName = [obj.class className];
    if (![objectClassName isEqualToString:expected]) {
        @throw [NSException exceptionWithName:@"RLMException" reason:@"Attempting to insert wrong object type"
                                     userInfo:@{@"expected class" : expected, @"actual class" : objectClassName}];
    }
}

- (void)addObject:(RLMObject *)object {
    RLMValidateObjectClass(object, self.objectClassName);
    if (object.realm != self.realm) {
        [self.realm addObject:object];
    }
    _backingLinkView->add(object.objectIndex);
}

- (void)insertObject:(RLMObject *)object atIndex:(NSUInteger)index {
    RLMValidateObjectClass(object, self.objectClassName);
    if (object.realm != self.realm) {
        [self.realm addObject:object];
    }
    _backingLinkView->insert(index, object.objectIndex);
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    if (index >= _backingLinkView->size()) {
        @throw [NSException exceptionWithName:@"RLMException"
                                       reason:@"Trying to remove object at invalid index" userInfo:nil];
    }
    _backingLinkView->remove(index);
}

- (void)removeLastObject {
    size_t size = _backingLinkView->size();
    if (size > 0){
        _backingLinkView->remove(size-1);
    }
}

- (void)removeAllObjects {
    _backingLinkView->clear();
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(RLMObject *)object {
    RLMValidateObjectClass(object, self.objectClassName);
    if (index >= _backingLinkView->size()) {
        @throw [NSException exceptionWithName:@"RLMException"
                                       reason:@"Trying to replace object at invalid index" userInfo:nil];
    }
    if (object.realm != self.realm) {
        [self.realm addObject:object];
    }
    _backingLinkView->set(index, object.objectIndex);
}

- (NSString *)JSONString {
    @throw [NSException exceptionWithName:@"RLMNotImplementedException"
                                   reason:@"Not yet implemented" userInfo:nil];
}

@end


