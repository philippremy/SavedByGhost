//
//  MTLFrameRenderer.metal
//  SavedByGhostKit
//
//  Copyright (C)  Philipp Remy 2026 - Present
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut frameRenderVertex(uint vertexID [[vertex_id]])
{
    constexpr float2 positions[4] = {
        {-1.0, -1.0},
        { 1.0, -1.0},
        {-1.0,  1.0},
        { 1.0,  1.0}
    };

    constexpr float2 texCoords[4] = {
        {0.0, 1.0},
        {1.0, 1.0},
        {0.0, 0.0},
        {1.0, 0.0}
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 frameRenderFragment(
    VertexOut in [[stage_in]],
    texture2d<float> frameTexture [[texture(0)]],
    constant float4& ghostColor [[buffer(0)]]
)
{
    constexpr sampler s(
        mag_filter::linear,
        min_filter::linear
    );
    
    float4 color = frameTexture.sample(s, in.texCoord);
    float4 out;
    
    constexpr float4 clearColor = float4(0.0, 0.0, 0.0, 0.0);
    
    float backgroundDistance = distance(color.rgb, float3(0.0));
    float ghostOutlineDistance = distance(color.rgb, float3(0.0, 0.0, 0.898));
    
    if (backgroundDistance <= 0.5)
        out = clearColor;
    else if (ghostOutlineDistance <= 0.5)
        out = ghostColor;
    else
        out = color;

    return out;
}
