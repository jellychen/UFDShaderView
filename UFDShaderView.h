//
//  UFDShaderView.h
//  UFDShaderView
//
//  Created by Ulrik Damm on 24/9/13.
//  Copyright (c) 2013 Robocat. All rights reserved.
//

#import <UIKit/UIKit.h>

/*!
 * Example fragment shader source. Pass this to -loadFragmentShader:error: if you just want to see something fancy happen.
 * Source from http://glsl.heroku.com.
 */
static NSString * const kUFDShaderViewExampleFragmentShaderSource = 
@"  precision mediump float;																		"
@"  																								"
@"  uniform float time;																				"
@"  uniform vec2 touch;																				"
@"  uniform vec2 resolution;																		"
@"  																								"
@"  void main(void) {																				"
@"  	vec2 pos = gl_FragCoord.xy / resolution;													"
@"  	float amnt = 200.0;																			"
@"  	float nd = 0.0;																				"
@"  	vec4 cbuff = vec4(0.0);																		"
@"  																								"
@"  	for (float i = 0.0; i < 5.0; i++) {															"
@"  		nd = sin(3.14 * 0.8 * pos.x + (i * 0.1 + sin(time) * 0.8) + time) * 0.4 + 0.1 + pos.x;  "
@"  		amnt = 1.0 / abs(nd - pos.y) * 0.01;                                                    "
@"  		cbuff += vec4(amnt, amnt * 0.3, amnt * pos.y, 081.0);                                   "
@"  	}																							"
@"  																								"
@"  	gl_FragColor = cbuff;																		"
@"  }																								"
@"  																								";

/*!
 * Used for specify the redraw framerate of a UFDShaderView.
 */
typedef enum {
	kUFDShaderViewFramerate30FPS,
	kUFDShaderViewFramerate60FPS
} UFDShaderViewFramerate;

/*!
 * View for rendering an OpenGL shader.
 */
@interface UFDShaderView : UIView

/*!
 * The framerate to render the view at. Options are 30 or 60 frames per second.
 */
@property (assign, nonatomic) UFDShaderViewFramerate framerate;

/*!
 * Wether or not the view is continiously redrawing.
 * For manual redrawing, set to NO and use -redraw.
 */
@property (assign, nonatomic, getter = isAnimating) BOOL animating;

/*!
 * Load the fragment shader source code from the specified string.
 * This will also initialize the OpenGL view if it isn't already.
 * The view will not draw anything before this method has been called.
 * See the documentation for names of available vayings and uniforms.
 * @param shaderSource The source code as a string, typically loaded from a GLSL file.
 * @param error Set if there was an error either with the OpenGL initialization, or the GLSL compilation/linking.
 */
- (void)loadFragmentShader:(NSString *)shaderSource error:(out NSError **)error;

/*!
 * Redraws the OpenGL view. Does nothing if animation is running, since it will automatically redraw.
 */
- (void)redraw;

@end
