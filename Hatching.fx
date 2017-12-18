float time : TIME;

float4x4 matWorld              : WORLD;
float4x4 matWorldInverse       : WORLDINVERSE;
float4x4 matWorldView          : WORLDVIEW;
float4x4 matWorldViewProject   : WORLDVIEWPROJECTION;
float4x4 matView               : VIEW;
float4x4 matViewInverse        : VIEWINVERSE;
float4x4 matProject            : PROJECTION;
float4x4 matProjectInverse     : PROJECTIONINVERSE;
float4x4 matViewProject        : VIEWPROJECTION;
float4x4 matViewProjectInverse : VIEWPROJECTIONINVERSE;

float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset  = 0.5 / ViewportSize;
static float2 ViewportOffset2 = 1.0 / ViewportSize;
static float  ViewportAspect  = ViewportSize.x / ViewportSize.y;

texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	bool AntiAlias = false;
	string Format = "A2R10G10B10";
	int Miplevels = 0;
>;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET<
	float2 ViewportRatio = {1.0,1.0};
	string Format = "D24S8";
>;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;   MagFilter = LINEAR;   MipFilter = LINEAR;
	AddressU  = CLAMP;  AddressV = CLAMP;
};

texture Hatch0<string ResourceName = "shader/textures/hatch_0.jpg";>;
texture Hatch1<string ResourceName = "shader/textures/hatch_1.jpg";>;
texture Hatch2<string ResourceName = "shader/textures/hatch_2.jpg";>;
sampler HatchSamp0 = sampler_state {
	texture = <Hatch0>; 
	MAXANISOTROPY = 16; 
	MINFILTER = ANISOTROPIC; MAGFILTER = ANISOTROPIC; MIPFILTER = ANISOTROPIC;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
sampler HatchSamp1 = sampler_state {
	texture = <Hatch1>; 
	MAXANISOTROPY = 16; 
	MINFILTER = ANISOTROPIC; MAGFILTER = ANISOTROPIC; MIPFILTER = ANISOTROPIC;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
sampler HatchSamp2 = sampler_state {
	texture = <Hatch2>; 
	MAXANISOTROPY = 16; 
	MINFILTER = ANISOTROPIC; MAGFILTER = ANISOTROPIC; MIPFILTER = ANISOTROPIC;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
texture HatchingMap : OFFSCREENRENDERTARGET<
	string Description = "Hatching";
	float2 ViewportRatio = {1.0, 1.0};
	string Format = "G16R16F";
	float4 ClearColor = { 1, 1, 1, 1 };
	float ClearDepth = 1.0;
	string DefaultEffect =
		"self = hide;"
		"*fog.pmx=hide;"
		"*controller*.pmx=hide;"
		"*editor*.pmx=hide;"
		"Volumetric*.pmx=hide;"
		"*.pmx=Hatching/Hatching 1.0.fx;";
>;
sampler HatchingMapSamp = sampler_state {
	texture = <HatchingMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

float mLoopsP : CONTROLOBJECT<string name="HatchingController.pmx"; string item = "Loops+";>;
float mLoopsM : CONTROLOBJECT<string name="HatchingController.pmx"; string item = "Loops-";>;
float mContrastP : CONTROLOBJECT<string name="HatchingController.pmx"; string item = "Contrast+";>;
float mContrastM : CONTROLOBJECT<string name="HatchingController.pmx"; string item = "Contrast-";>;
float mThresholdP : CONTROLOBJECT<string name="HatchingController.pmx"; string item = "Threshold+";>;
float mThresholdM : CONTROLOBJECT<string name="HatchingController.pmx"; string item = "Threshold-";>;

static const float mLoops = lerp(lerp(10, 20, mLoopsP), 0, mLoopsM);
static const float mContrast = lerp(lerp(0.5, 1.0, mContrastP), 0.0, mContrastM);
static const float mThreshold = lerp(lerp(0.5, 0.0, mThresholdP), 1.0, mThresholdM);

float luminance(float3 rgb)
{
	return dot(rgb, float3(0.299f, 0.587f, 0.114f));
}

float2 magnify(float2 uv, float2 resolution = float2(256,256))
{
    uv *= resolution; 
    return (saturate(frac(uv) / saturate(fwidth(uv))) + floor(uv) - 0.5) / resolution;
}

// Under BSD license Copyright (c) 2014, Chase Zhang
// https://github.com/shanzi/sketch-rendering
float shade(float shading, float2 uv) 
{
	float shadingFactor;
	float stepSize = 1.0 / 3.0;
	float alpha = 0.0;
	float scaleWhite = 0.0;
	float scaleHatch0 = 0.0;
	float scaleHatch1 = 0.0;
	float scaleHatch2 = 0.0;

	if (shading <= stepSize)
	{
		alpha = 3.0 * shading;
		scaleHatch1 = alpha;
		scaleHatch2 = 1.0 - alpha;
	}
	else if (shading > stepSize && shading <= 2.0 * stepSize)
	{
		alpha = 3.0 * (shading - stepSize);
		scaleHatch0 = alpha;
		scaleHatch1 = 1.0 - alpha;
	}
	else if (shading > 2.0 * stepSize)
	{
		alpha = 3.0 * (shading - stepSize * 2.0);
		scaleWhite = alpha;
		scaleHatch0 = 1.0 - alpha;
	}

	shadingFactor = scaleWhite + 
	tex2D(HatchSamp0, magnify(uv)).r * scaleHatch0+
	tex2D(HatchSamp1, magnify(uv)).r * scaleHatch1+
	tex2D(HatchSamp2, magnify(uv)).r * scaleHatch2;

	return shadingFactor;
}

void HatchingVS(
	in float4 Position : POSITION,
	in float4 Texcoord : TEXCOORD0,
	in float3 Normal : NORMAL,
	out float4 oTexcoord0 : TEXCOORD0,
	out float3 oTexcoord1   : TEXCOORD1,
	out float4 oPosition : POSITION)
{
	oTexcoord0 = Texcoord;
	oTexcoord1 = Normal;
	oPosition = Position;
}

float4 HatchingPS(in float2 coord: TEXCOORD0) : COLOR
{
	float3 screen = tex2D(ScnSamp, coord).rgb;
	float lum = luminance(screen) + mThreshold;
	float2 uv = tex2D(HatchingMapSamp, coord).xy;
	float hatching = shade(lum, uv * mLoops) * shade(lum, uv.yx * mLoops * ViewportAspect) * mContrast + (1 - mContrast);

	return float4(hatching.xxx, 1);
}

float Script : STANDARDSGLOBAL<
	string ScriptOutput = "color";
	string ScriptClass  = "scene";
	string ScriptOrder  = "postprocess";
> = 0.8;

const float4 ClearColor = 0.0;
const float ClearDepth = 1.0;

technique HatchingTech<
	string Script = 
	"RenderColorTarget=;"
	"ClearSetColor=ClearColor;"
	"ClearSetDepth=ClearDepth;"

	"RenderColorTarget=ScnMap;"
	"Clear=Color;"
	"Clear=Depth;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"ScriptExternal=Color;"

	"RenderColorTarget=;"
	"RenderDepthStencilTarget=;"
	"Pass=HatchingEffect;"
;>{
	pass HatchingEffect<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 HatchingVS();
		PixelShader  = compile ps_3_0 HatchingPS();
	}
}