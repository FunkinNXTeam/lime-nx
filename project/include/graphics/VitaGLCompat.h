#pragma once
#ifdef HX_VITA

#include <vitaGL.h>

#ifndef APIENTRY
#define APIENTRY
#endif

#ifndef GLDEBUGPROC
typedef void (APIENTRY *GLDEBUGPROC)(GLenum source, GLenum type, GLuint id,
    GLenum severity, GLsizei length, const GLchar *message, const void *userParam);
#endif

#ifndef GLDEBUGPROCARB
typedef GLDEBUGPROC GLDEBUGPROCARB;
#endif

static inline GLboolean glIsBuffer(GLuint buffer) { return GL_FALSE; }
static inline GLboolean glIsShader(GLuint shader) { return glIsProgram(shader) ? GL_FALSE : GL_TRUE; }
static inline void glValidateProgram(GLuint program) {}
static inline void glGetUniformfv(GLuint program, GLint location, GLfloat *params) {}
static inline void glGetUniformiv(GLuint program, GLint location, GLint *params) {}
static inline void glGetTexParameterfv(GLenum target, GLenum pname, GLfloat *params) {}
static inline void glGetTexParameteriv(GLenum target, GLenum pname, GLint *params) {}
static inline void glGetShaderPrecisionFormat(GLenum shadertype, GLenum precisiontype,
    GLint *range, GLint *precision) {
    if (range) { range[0] = range[1] = 0; }
    if (precision) *precision = 0;
}
static inline void glGetRenderbufferParameteriv(GLenum target, GLenum pname, GLint *params) {}
static inline void glDetachShader(GLuint program, GLuint shader) {}
static inline void glCompressedTexSubImage2D(GLenum target, GLint level,
    GLint xoffset, GLint yoffset, GLsizei width, GLsizei height,
    GLenum format, GLsizei imageSize, const void *data) {}
static inline void glBlendColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha) {}

#endif // HX_VITA
