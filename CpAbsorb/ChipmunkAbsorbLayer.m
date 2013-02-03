//
//  ChipmunkAbsorbLayer.m
//  GameTutorial
//
//  Created by Ian Fan on 24/01/13.
//
//

#import "ChipmunkAbsorbLayer.h"
#import "chipmunk_unsafe.h"

@implementation ChipmunkAbsorbLayer


#define GRABABLE_MASK_BIT (1<<31)
#define NOT_GRABABLE_MASK (~GRABABLE_MASK_BIT)

+(CCScene *) scene {
	CCScene *scene = [CCScene node];
	ChipmunkAbsorbLayer *layer = [ChipmunkAbsorbLayer node];
	[scene addChild: layer];
  
	return scene;
}

#pragma mark -
#pragma mark Chipmunk objects

#define DENSITY (1.0e-2)
NSString *COLLISION_ID = @"COLLISION_ID";

-(void)setChipmunkObjects {
  CGSize winSize = [CCDirector sharedDirector].winSize;
  
  for(int i=0; i<5000; i++){
		cpFloat radius = CCRANDOM_0_1()*12+8;
		cpFloat mass = DENSITY*radius*radius;
    //		cpFloat moment = cpMomentForCircle(10*mass, 0, radius, cpvzero);
    
		ChipmunkBody *body = [ChipmunkBody bodyWithMass:mass andMoment:INFINITY];
		body.pos = cpv(CCRANDOM_0_1()*winSize.width, CCRANDOM_0_1()*winSize.height);
		body.vel = cpvmult(cpv(2*CCRANDOM_0_1()-1, 2*CCRANDOM_0_1()-1), 20.0);
    //    body.angVel = (2*CCRANDOM_0_1()-1)*1;
		
		ChipmunkShape *shape = [ChipmunkCircleShape circleWithBody:body radius:radius offset:cpvzero];
		shape.elasticity = 1.0;
		shape.friction = 0.0;
		shape.collisionType = COLLISION_ID;
		
		if(![_space shapeTest:shape]){
			[_space add:body];
			[_space add:shape];
		}
	}
	
	[_space addCollisionHandler:self typeA:COLLISION_ID typeB:COLLISION_ID begin:nil preSolve:@selector(preSolve:space:) postSolve:nil separate:nil];
}

-(bool)preSolve:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
{
	// Get the two colliding shapes
	CHIPMUNK_ARBITER_GET_SHAPES(arbiter, ball1, ball2);
	ChipmunkCircleShape *bigger = (id)ball1;
	ChipmunkCircleShape *smaller = (id)ball2;
	
	if(smaller.radius > bigger.radius){
		ChipmunkCircleShape *tmp = bigger;
		bigger = smaller;
		smaller = tmp;
	}
	
	cpFloat r1 = bigger.radius;
	cpFloat r2 = smaller.radius;
	cpFloat area = r1*r1 + r2*r2;
	cpFloat dist = cpfmax(cpvdist(bigger.body.pos, smaller.body.pos), cpfsqrt(area));
	
	cpFloat r1_new = (2.0*dist + cpfsqrt(8.0*area - 4.0*dist*dist))/4.0;
	
	// First update the velocity by gaining the absorbed momentum.
	cpFloat old_mass = bigger.body.mass;
	cpFloat new_mass = r1_new*r1_new*DENSITY;
	cpFloat gained_mass = new_mass - old_mass;
	bigger.body.vel = cpvmult(cpvadd(cpvmult(bigger.body.vel, old_mass), cpvmult(smaller.body.vel, gained_mass)), 1.0/new_mass);
	
	bigger.body.mass = new_mass;
	cpCircleShapeSetRadius(bigger.shape, r1_new);
  
	cpFloat r2_new = dist - r1_new;
	if(r2_new > 0.0){
		smaller.body.mass = r2_new*r2_new*DENSITY;
		cpCircleShapeSetRadius(smaller.shape, r2_new);
	} else {
		// If smart remove is called from within a callback, it will schedule a post-step callback to perform the removal automatically.
		[space smartRemove:smaller];
		[space smartRemove:smaller.body];
	}
	
	return FALSE;
}

#pragma mark -
#pragma mark Touch Event

-(void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  for(UITouch *touch in touches){
    CGPoint point = [touch locationInView:[touch view]];
    point = [[CCDirector sharedDirector]convertToGL:point];
    [_multiGrab beginLocation:point];
  }
}

-(void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  for(UITouch *touch in touches){
    CGPoint point = [touch locationInView:[touch view]];
    point = [[CCDirector sharedDirector]convertToGL:point];
    [_multiGrab updateLocation:point];
  }
}

-(void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	for(UITouch *touch in touches){
    CGPoint point = [touch locationInView:[touch view]];
    point = [[CCDirector sharedDirector]convertToGL:point];
    [_multiGrab endLocation:point];
  }
}

-(void)ccTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event {
  [self ccTouchEnded:touch withEvent:event];
}

#pragma mark -
#pragma mark Update

-(void)update:(ccTime)dt {
  [_space step:dt];
}

#pragma mark -
#pragma mark CpDebugLayer

-(void)setChipmunkDebugLayer {
  [self addChild:[CPDebugLayer debugLayerForSpace:_space.space options:nil] z:999];
}

#pragma mark -
#pragma mark ChipmunkMultiGrab

-(void)setChipmunkMultiGrab {
  cpFloat grabForce = 1e5;
  cpFloat smoothing = cpfpow(0.3,60);
  
  _multiGrab = [[ChipmunkMultiGrab alloc]initForSpace:_space withSmoothing:smoothing withGrabForce:grabForce];
  _multiGrab.layers = GRABABLE_MASK_BIT;
  _multiGrab.grabFriction = grabForce*0.1;
  _multiGrab.grabRotaryFriction = 1e3;
  _multiGrab.grabRadius = 20.0;
  _multiGrab.pushMass = 1.0;
  _multiGrab.pushFriction = 0.7;
  _multiGrab.pushMode = FALSE;
}

#pragma mark -
#pragma mark ChipmunkSpace

-(void)setChipmunkSpace {
  CGSize winSize = [CCDirector sharedDirector].winSize;
  
  _space = [[ChipmunkSpace alloc]init];
  [_space addBounds:CGRectMake(0, 0, winSize.width, winSize.height) thickness:60.0 elasticity:1.0 friction:0.2 layers:NOT_GRABABLE_MASK group:nil collisionType:nil];
  _space.gravity = cpv(0, -50);
  _space.iterations = 30;
}

/*
 Target: Set a lots of ChipmunkCircleShape absorb each other while two of them are touching.
 
 1. Set ChipmunkSpace, ChipmunkMultiGrab, ChipmunkDebugLayer as usual.
 2. Set A lot of ChupmunkCircleShape in the space.
 3. Set Handler to detect while two of them are touching.
 4. Set Absorb math rule to make the bigger one absorb the smaller one.
 */

#pragma mark -
#pragma mark Init

-(id) init {
	if( (self = [super init]) ) {
    self.isTouchEnabled = YES;
    
    [self setChipmunkSpace];
    
    [self setChipmunkMultiGrab];
    
    [self setChipmunkDebugLayer];
    
    [self setChipmunkObjects];
    
    [self schedule:@selector(update:)];
    
    self.isTouchEnabled = YES;
	}
  
	return self;
}

- (void) dealloc {
  [_space release];
  [_multiGrab release];
  
	[super dealloc];
}

@end
