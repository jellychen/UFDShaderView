//
//  UFDShaderView.m
//  UFDShaderView
//
//  Created by Ulrik Damm on 24/9/13.
//  Copyright (c) 2013 Robocat. All rights reserved.
//

#import "UFDShaderView.h"
#import <OpenGLES/ES2/gl.h>
#import <QuartzCore/QuartzCore.h>

static const char * const vertexShaderSource = 
"attribute vec4 attr_position;		"
"									"
"void main() {						"
"	gl_Position = attr_position;	"
"}									"
"									";

static GLfloat squareVertices[] = {
	 1, -1,  0,
	 1,  1,  0,
	-1, -1,  0,
	-1,  1,  0,
};

static GLubyte squareIndicies[] = { 0, 1, 2, 3 };

@interface UFDShaderView ()

@property (assign, nonatomic) BOOL setupComplete;

@property (strong, nonatomic) CADisplayLink *displayLink;
@property (strong, nonatomic) EAGLContext *glContext;

@property (assign, nonatomic) GLuint framebufferId;
@property (assign, nonatomic) GLuint renderbufferId;
@property (assign, nonatomic) GLuint vertexShaderId;
@property (assign, nonatomic) GLuint shaderProgramId;
@property (assign, nonatomic) GLuint vertexBufferId;
@property (assign, nonatomic) GLuint vertexIndexBufferId;

@property (assign, nonatomic) GLuint attrPositionLoc;
@property (assign, nonatomic) GLuint uniTimeLoc;
@property (assign, nonatomic) GLuint uniResolutionLoc;
@property (assign, nonatomic) GLuint uniTouchLoc;

@property (strong, nonatomic) UITouch *currentTouch;
@property (assign, nonatomic) CGPoint touchLocation;

@end

@implementation UFDShaderView

+ (Class)layerClass {
	return [CAEAGLLayer class];
}

- (void)loadFragmentShader:(NSString *)shaderSource error:(out NSError **)error {
	if (![self setupComplete]) {
//		[self setContentScaleFactor:[[UIScreen mainScreen] scale]];
		
		self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if (!self.glContext || ![EAGLContext setCurrentContext:self.glContext]) {
			self.glContext = nil;
			*error = [NSError errorWithDomain:@"dk.ufd.shaderview" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"Couldn't set OpenGL context" }];
			return;
		}
		
		glGenRenderbuffers(1, &_renderbufferId);
		glBindRenderbuffer(GL_RENDERBUFFER, self.renderbufferId);
		[self.glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
		
		glGenFramebuffers(1, &_framebufferId);
		glBindFramebuffer(GL_FRAMEBUFFER, self.framebufferId);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.renderbufferId);
		
		GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if (framebufferStatus != GL_FRAMEBUFFER_COMPLETE) {
			NSString *errorString = [NSString stringWithFormat:@"Incomplete framebuffer: %04x", framebufferStatus];
			*error = [NSError errorWithDomain:@"dk.ufd.shaderView" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorString }];
			glDeleteFramebuffers(1, &_framebufferId);
			glDeleteRenderbuffers(1, &_renderbufferId);
			return;
		}
		
		NSError *compilerError = nil;
		self.vertexShaderId = [self shaderWithSource:vertexShaderSource shaderType:GL_VERTEX_SHADER error:&compilerError];
		
		if (compilerError) {
			NSString *errorString = [NSString stringWithFormat:@"Vertex shader compilation failed with error: '%@'", compilerError.localizedDescription];
			*error = [NSError errorWithDomain:@"dk.ufd.shaderview" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorString }];
			glDeleteFramebuffers(1, &_framebufferId);
			glDeleteRenderbuffers(1, &_renderbufferId);
			return;
		}
		
		glGenBuffers(1, &_vertexBufferId);
		glBindBuffer(GL_ARRAY_BUFFER, self.vertexBufferId);
		glBufferData(GL_ARRAY_BUFFER, sizeof(squareVertices), squareVertices, GL_STATIC_DRAW);
		
		glGenBuffers(1, &_vertexIndexBufferId);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.vertexIndexBufferId);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(squareIndicies), squareIndicies, GL_STATIC_DRAW);
		
		self.setupComplete = YES;
	}
	
	const char *fragmentShaderSource = [shaderSource cStringUsingEncoding:NSUTF8StringEncoding];
	NSError *compilerError;
	GLuint fragmentShaderId = [self shaderWithSource:fragmentShaderSource shaderType:GL_FRAGMENT_SHADER error:&compilerError];
	
	if (compilerError) {
		NSString *errorString = [NSString stringWithFormat:@"Fragment shader compilation failed with error: '%@'", compilerError.localizedDescription];
		*error = [NSError errorWithDomain:@"dk.ufd.shaderview" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorString }];
		return;
	}
	
	NSError *linkError;
	self.shaderProgramId = [self programWithVertexShader:self.vertexShaderId fragmentShader:fragmentShaderId error:&linkError];
	
	if (linkError) {
		NSString *errorString = [NSString stringWithFormat:@"Program linking failed with error: '%@'", linkError.localizedDescription];
		*error = [NSError errorWithDomain:@"dk.ufd.shaderview" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorString }];
		return;
	}
	
	glUseProgram(self.shaderProgramId);
	
	self.attrPositionLoc = glGetAttribLocation(self.shaderProgramId, "attr_position");
	self.uniTimeLoc = glGetUniformLocation(self.shaderProgramId, "time");
	self.uniResolutionLoc = glGetUniformLocation(self.shaderProgramId, "resolution");
	self.uniTouchLoc = glGetUniformLocation(self.shaderProgramId, "touch");
	
	GLenum glError = glGetError();
	if (glError != GL_NO_ERROR) {
		NSString *errorString = [NSString stringWithFormat:@"OpenGL error: %04x", glError];
		*error = [NSError errorWithDomain:@"dk.ufd.shaderview" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorString }];
		return;
	}
	
	if ([self isAnimating]) {
		[self setupDisplayLink];
	} else {
		[self redraw];
	}
}

- (void)redraw {
	[self render:nil];
}

- (void)render:(CADisplayLink *)sender {
	[EAGLContext setCurrentContext:self.glContext];
	
	glClearColor(0.5, 0.5, 0.5, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	glViewport(0, 0, self.bounds.size.width, self.bounds.size.height);
	
	glEnableVertexAttribArray(self.attrPositionLoc);
	
	glUniform1f(self.uniTimeLoc, self.displayLink.timestamp);
	glUniform2f(self.uniResolutionLoc, self.bounds.size.width, self.bounds.size.height);
	glUniform2f(self.uniTouchLoc, self.touchLocation.x / self.bounds.size.width, 1-self.touchLocation.y / self.bounds.size.height);
	glVertexAttribPointer(self.attrPositionLoc, 3, GL_FLOAT, GL_FALSE, 0, (void *)(sizeof(GLfloat) * 0));
	glDrawElements(GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, 0);
	
	glDisableVertexAttribArray(self.attrPositionLoc);
	
	[self.glContext presentRenderbuffer:GL_RENDERBUFFER];
	
	GLenum glError = glGetError();
	if (glError != GL_NO_ERROR) {
		NSString *errorString = [NSString stringWithFormat:@"OpenGL error: %04x", glError];
		NSLog(@"%@", errorString);
		return;
	}
}

- (void)setupDisplayLink {
	if (!self.displayLink) {
		self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
		[self setFramerate:self.framerate];
		[self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
	}
}

#pragma mark - Properties

- (void)setFramerate:(UFDShaderViewFramerate)framerate {
	self.displayLink.frameInterval = (self.framerate == kUFDShaderViewFramerate30FPS? 2: 1);
}

- (void)setAnimating:(BOOL)animating {
	if (animating == [self isAnimating]) return;
	
	if (animating) {
		[self setupDisplayLink];
	} else {
		[self.displayLink invalidate];
		self.displayLink = nil;
	}
}

#pragma mark - Helpers

- (GLuint)shaderWithSource:(const char *)source shaderType:(GLenum)type error:(out NSError **)error {
	GLuint shaderId = glCreateShader(type);
	int sourceLength = strlen(source);
	glShaderSource(shaderId, 1, &source, &sourceLength);
	glCompileShader(shaderId);
	
	GLint compileStatus;
	glGetShaderiv(shaderId, GL_COMPILE_STATUS, &compileStatus);
	if (compileStatus != GL_TRUE) {
		GLchar buffer[512];
		glGetShaderInfoLog(shaderId, sizeof(buffer), NULL, buffer);
		
		NSString *errorString = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
		*error = [NSError errorWithDomain:@"dk.ufd.shaderview" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorString }];
		glDeleteShader(shaderId);
		return 0;
	}
	
	*error = nil;
	return shaderId;
}

- (GLuint)programWithVertexShader:(GLuint)vertexShaderId fragmentShader:(GLuint)fragmentShaderId error:(out NSError **)error {
	GLuint programId = glCreateProgram();
	glAttachShader(programId, vertexShaderId);
	glAttachShader(programId, fragmentShaderId);
	glLinkProgram(programId);
	
	GLint linkStatus;
	glGetProgramiv(programId, GL_LINK_STATUS, &linkStatus);
	if (linkStatus != GL_TRUE) {
		GLchar buffer[512];
		glGetProgramInfoLog(programId, sizeof(buffer), NULL, buffer);
		
		NSString *errorString = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
		*error = [NSError errorWithDomain:@"dk.ufd.shaderview" code:0 userInfo:@{ NSLocalizedDescriptionKey: errorString }];
		glDeleteProgram(programId);
		return 0;
	}
	
	*error = nil;
	return programId;
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	if (!self.currentTouch) {
		self.currentTouch = [touches anyObject];
		self.touchLocation = [self.currentTouch locationInView:self];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if ([touches containsObject:self.currentTouch]) {
		self.touchLocation = [self.currentTouch locationInView:self];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if ([touches containsObject:self.currentTouch]) {
		self.currentTouch = nil;
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	if ([touches containsObject:self.currentTouch]) {
		self.currentTouch = nil;
	}
}

@end
