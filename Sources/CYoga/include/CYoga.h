#pragma once

// CYoga.h — Subset da API C pública do Yoga que usaremos.
// Quando integrar a lib real, substitua este arquivo pelo yoga/Yoga.h oficial.
// https://github.com/facebook/yoga/blob/main/yoga/Yoga.h

#include <stdint.h>
#include <stddef.h>

typedef void* YGNodeRef;
typedef void* YGConfigRef;

typedef enum {
    YGFlexDirectionColumn,
    YGFlexDirectionColumnReverse,
    YGFlexDirectionRow,
    YGFlexDirectionRowReverse,
} YGFlexDirection;

typedef enum {
    YGEdgeLeft,
    YGEdgeTop,
    YGEdgeRight,
    YGEdgeBottom,
    YGEdgeAll,
} YGEdge;

typedef enum { YGDirectionLTR, YGDirectionRTL } YGDirection;

// Criação
YGNodeRef YGNodeNew(void);
void      YGNodeFree(YGNodeRef node);

// Inserção de filhos
void YGNodeInsertChild(YGNodeRef node, YGNodeRef child, uint32_t index);

// Estilo — flex
void YGNodeStyleSetFlexDirection(YGNodeRef node, YGFlexDirection direction);
void YGNodeStyleSetFlexGrow(YGNodeRef node, float flexGrow);
void YGNodeStyleSetGap(YGNodeRef node, YGEdge edge, float gap);

// Estilo — dimensões e padding
void YGNodeStyleSetWidth(YGNodeRef node, float width);
void YGNodeStyleSetHeight(YGNodeRef node, float height);
void YGNodeStyleSetPadding(YGNodeRef node, YGEdge edge, float padding);
void YGNodeStyleSetMargin(YGNodeRef node, YGEdge edge, float margin);

// Calcular layout
void YGNodeCalculateLayout(
    YGNodeRef node,
    float availableWidth,
    float availableHeight,
    YGDirection direction
);

// Resultados
float YGNodeLayoutGetLeft(YGNodeRef node);
float YGNodeLayoutGetTop(YGNodeRef node);
float YGNodeLayoutGetWidth(YGNodeRef node);
float YGNodeLayoutGetHeight(YGNodeRef node);
