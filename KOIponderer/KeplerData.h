//
//  KeplerData.h
//  KeplerIan
//
//  Created by Richard Nerf on 6/9/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#ifndef KeplerIan_KeplerData_h
#define KeplerIan_KeplerData_h

typedef struct _keplerData
{
    GLfloat time;
	GLfloat flux;
} keplerData;
typedef struct _keplerStack
{
    GLfloat time;
	GLfloat flux;
	GLint mux;
} keplerStack;

#endif
