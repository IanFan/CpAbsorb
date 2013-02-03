//
//  ChipmunkAbsorbLayer.h
//  GameTutorial
//
//  Created by Ian Fan on 24/01/13.
//
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import "ObjectiveChipmunk.h"
#import "CPDebugLayer.h"

@interface ChipmunkAbsorbLayer : CCLayer
{
  ChipmunkSpace *_space;
  ChipmunkMultiGrab *_multiGrab;
}

+(CCScene *) scene;

@end
