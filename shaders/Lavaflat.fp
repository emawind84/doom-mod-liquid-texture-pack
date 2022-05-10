mat3 GetTBN();
vec2 GetAutoscaleAt(vec2 texcoord);
vec2 ParallaxMap(mat3 tbn); 
vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord);
vec2 GetTopdiffusescaleAt(mat3 tbn);
vec2 GetbottomdiffusescaleAt(mat3 tbn);
vec3 GetTopMaskLayerCoord(mat3 tbn, vec2 texcoord);
vec2 GetNormalLiquidscrollposAt(mat3 tbn);
vec2 GetNormalLiquidscrollnegAt(mat3 tbn);
vec2 GetLiquidscrollposAt(mat3 tbn);
vec2 GetLiquidscrollnegAt(mat3 tbn);
vec2 GetLayerposAt(mat3 tbn);

////////////////////////////////////////////////////////////////////////////////
//////////////////material setup////////////////////////////////////////////////
Material ProcessMaterial()
{
	Material material;
	
	material.Base = vec4(0.0);
	material.Bright = vec4(0.0);
	//material.Glow = vec4(0.0);
	material.Normal = vec3(0.0);
	material.Specular = vec3(0.0);
	material.Glossiness = 0.0;
	material.SpecularLevel = 0.0;

    mat3 tbn = GetTBN(); 
	
	////Masktexture////
	vec4 Diffusemask = texture(Diffusemask,GetLayerposAt(tbn));//parallax texture (black / white)
	
	////Normaltexture For bottom layer////
	vec4 normalmapA = texture(Diffusedistortion, GetNormalLiquidscrollposAt(tbn)) * 0.15;
	vec4 normalmapB = texture(Diffusedistortion, GetNormalLiquidscrollnegAt(tbn)) * 0.15;
	vec4 normalmapbase = normalmapA + normalmapB;
	
	////generate diffuse base texture////
	vec4 DiffuseyposL = texture(Diffuse, (normalmapbase.xy + GetLiquidscrollposAt(tbn))) * 0.6;//diffuse texture scroll positive and brightness 
	vec4 DiffuseynegL = texture(Diffuse, (-normalmapbase.xy + GetLiquidscrollnegAt(tbn))) * 0.6;//diffuse texture scroll negetive and brightness 
	vec4 DiffuseyposXL = texture(Diffuse, (normalmapbase.xy + GetLiquidscrollposAt(tbn)) * 0.25) * 0.6;//diffuse texture scroll positive and brightness 
	vec4 DiffuseynegXL = texture(Diffuse, (-normalmapbase.xy + GetLiquidscrollnegAt(tbn)) * 0.25) * 0.6;//diffuse texture scroll negetive and brightness 
	vec4 DiffuseVec4 = clamp(DiffuseyposL + DiffuseynegL + DiffuseyposXL + DiffuseynegXL,0.0,1.0);//add diffuse textures togeter for generated effect
	
	////speculartexture////
	vec4 spectexture = texture(speculartexture, GetTopdiffusescaleAt(tbn));
	
	////generate diffuse top layer////
	vec4 Diffusetoplayer = spectexture;//top diffuse texture and scale value
	vec4 layerglow = vec4(0.35, 0.0, 0.0, 1.0);//RGBA
	vec4 Glowblend = clamp(layerglow * (clamp(Diffusemask * 40.0,0.0,1.0)) - (Diffusemask * 0.55),0.0,1.0);
	vec4 Diffusemasked = clamp(DiffuseVec4 - (clamp(Diffusemask * 40.0,0.0,1.0)),0.0,1.0);
	vec4 diffuselayermasked = Diffusetoplayer * (clamp(Diffusemask * 10.0,0.0,1.0));
	vec4 Diffusefinal = clamp(diffuselayermasked + Diffusemasked + Glowblend,0.0,1.0);
	
	//// generate brightmap texture////
	vec4 brightmapmask = clamp(Diffusefinal + 0.6 - (clamp(Diffusemask * 20.0,0.0,1.0)) + (clamp(Glowblend * 2.0,0.0,1.0)),0.0,1.0);
	
	////generate specular texure masked////
	vec4 Specfinal = spectexture * Diffusemask;//specular texture values multiplied by the diffuse mask texture ( 0.0 = black / 1.0 = white)

	////materials////
	material.Base = Diffusefinal;
    material.Normal = GetBumpedNormal(tbn, GetLayerposAt(tbn));
	material.Bright = brightmapmask; 
#if defined(SPECULAR)
    material.Specular = Specfinal.rgb;
    material.Glossiness = uSpecularMaterial.x;
    material.SpecularLevel = uSpecularMaterial.y;
#endif
	return material;
}

////////////////////////////////////////////////////////////////////////////////
////////Tangent/bitangent/normal space to world space transform matrix//////////
mat3 GetTBN()
{
    vec3 n = normalize(vWorldNormal.xyz);
    vec3 p = pixelpos.xyz;
    vec2 uv = vTexCoord.st;

    // get edge vectors of the pixel triangle
    vec3 dp1 = dFdx(p);
    vec3 dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = dFdy(uv);

    // solve the linear system
    vec3 dp2perp = cross(n, dp2); // cross(dp2, n);
    vec3 dp1perp = cross(dp1, n); // cross(n, dp1);
    vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;

    // construct a scale-invariant frame
    float invmax = inversesqrt(max(dot(t,t), dot(b,b)));
    return mat3(t * invmax, b * invmax, n);
}

////////////////////////////////////////////////////////////////////////////////
///////////////////////base diffuse texture animation///////////////////////////
////diffuse normal map
vec2 GetNormalLiquidscrollposAt(mat3 tbn)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(tbn);							
	vec2 offset = vec2(0,0);
	offset.x = texCoord.x * 1.5 + (timer * 0.125);//scroll direction and speed    
	offset.y = texCoord.y * 1.5;    
    return(texCoord += offset);
}

vec2 GetNormalLiquidscrollnegAt(mat3 tbn)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(tbn);									
	vec2 offset = vec2(0,0);
	offset.x = texCoord.x + (timer * -0.125);//scroll direction and speed   
	offset.y = texCoord.y;
    return(texCoord += offset);
}
////diffuse color
vec2 GetLiquidscrollposAt(mat3 tbn)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(tbn);							
	vec2 offset = vec2(0,0);
	offset.y = texCoord.y * 1.5 + (timer * 0.175);//scroll direction and speed  
	offset.x = texCoord.x * 1.5;
    return(texCoord += offset);
}

vec2 GetLiquidscrollnegAt(mat3 tbn)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(tbn);									
	vec2 offset = vec2(0,0);
	offset.y = texCoord.y + (timer * -0.175);//scroll direction and speed 
	offset.x = texCoord.x;
    return(texCoord += offset);
}

////////////////////////////////////////////////////////////////////////////////
/////////////////////Normal texture Generate and normal math ///////////////////
vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord)
{
#if defined(NORMALMAP)
	vec3 Diffusemask = texture(Diffusemask,GetLayerposAt(tbn)).xyz;//parallax texture (black / white)
	vec3 layermasknormal = (texture(layermasknormal, GetLayerposAt(tbn)) * 0.5).xyz;//normalmap for Diffusemask mask based on parallax map
	vec3 normalmap = (texture(normaltexture, GetTopdiffusescaleAt(tbn)) * 0.5).xyz;//normalmap for diffuse top layer texture
	vec3 normalmapmaksed = normalmap * clamp(Diffusemask * 2.0,0.0,1.0);//remove diffuse normalmap color based on layermask brightness
	vec3 normalcombined = clamp(layermasknormal + normalmapmaksed,0.0,1.0);//add the adjusted diffuse normal map color to the layermask normal map color
    normalcombined = normalcombined * 255./127. - 128./127.; // Math so "odd" because 0.5 cannot be precisely described in an unsigned format
    normalcombined.xy *= vec2(1, -1); //flip Y
    return normalize(tbn * normalcombined);
#else
    return normalize(vWorldNormal.xyz);
#endif
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////layer mask texture scale////////////////////////////////
vec2 GetLayerposAt(mat3 tbn)
{        																				
    return ParallaxMap(tbn) * 0.75;//change scale of layer mask texture here  -----------------															
}																							//
float GetLayerscaleAt(vec2 currentTexCoords)												//numbers must match
{																							//
    return 0.75;//change scale of Layer mask texture here -------------------------------------
}

////////////////////////////////////////////////////////////////////////////////
///////////////top layer diffuse texture scale//////////////////////////////////
vec2 GetTopdiffusescaleAt(mat3 tbn)
{																		
    return ParallaxMap(tbn) * 15.0;//change scale of top diffuse texture here 
}

////////////////////////////////////////////////////////////////////////////////
///////////////bottom diffuse texture scale/////////////////////////////////////
vec2 GetbottomdiffusescaleAt(mat3 tbn)
{																			
    return ParallaxMap(tbn) * 4.0;//change scale of bottom diffuse texture here
}

////////////////////////////////////////////////////////////////////////////////
/////////////////main parallax texture scale and texcoord setup/////////////////
vec2 GetAutoscaleAt(vec2 currentTexCoords) //////sets the main parallax texture scale size which all the other texture scale values are based on.
{
	vec2 PXCoord = vTexCoord.st;
	PXCoord.x = PXCoord.x * 0.2;//scale main parallax texture here
	PXCoord.y = PXCoord.y * 0.2;//scale main parallax texture here 
	vec2 offset = vec2(0,0);
	const float pi = 3.14159265358979323846;
	//		Frequency         Animation Speed     Amplitude        
	//sin(pi * 4.05 * (texcoord.x + (timer * 0.15)) * 0.025)
	offset.y = sin(pi * (PXCoord.x + (timer * 0.05)) * 0.05);                     
	offset.x = sin(pi * (PXCoord.y + (timer * 0.05)) * 0.05);
	PXCoord += offset;															
    return PXCoord;
}

////////////////////////////////////////////////////////////////////////////////
///////////////////Parallax texture color setup/////////////////////////////////
float GetDisplacementAt(vec2 currentTexCoords)//adjust parallax color and animation texcoord here
{
	vec2 texCoord = vTexCoord.st;
	vec2 PXcoord = GetAutoscaleAt(currentTexCoords).xy;
	vec2 offset = vec2(0,0);
	offset.y =  PXcoord.y + timer * 0.3; //parallax texture scroll direction and speed
	offset.x =  PXcoord.x + timer * 0.025; //parallax texture scroll direction and speed
	float parallax = texture(Parallax, offset).r;//main parallax texture with adjusted texture offset
	float Diffusemask = texture(Diffusemask, (PXcoord * GetLayerscaleAt(currentTexCoords))).r;//top layer parallax texture
	float parallaxwave = clamp(parallax - Diffusemask,0.0,1.0);//clamp used to keep values between 0 and 1
	float parallaxcombined = clamp(parallaxwave + Diffusemask,0.0,1.0);//blend texture brightness and keep values between 0 and 1
    return 1.0 - (parallaxcombined);
}

////////////////////////////////////////////////////////////////////////////////
///////////////////Parallax/////////////////////////////////////////////////////
vec2 ParallaxMap(mat3 tbn)
{
    // Calculate fragment view direction in tangent space
	ivec2 texSize = textureSize(tex, 0);
    mat3 invTBN = transpose(tbn);
    vec3 V = normalize(invTBN * (uCameraPos.xyz - pixelpos.xyz));
	vec2 texCoord = vTexCoord.st;
    vec2 PXcoord = GetAutoscaleAt(texCoord).xy;
	vec2 parallaxScale = vec2(2.5);
	float minLayers = 4.0;
    float maxLayers = 16.0;
	float viewscale = 0.0;
	float viewscaleX = float (texSize.x / texSize.y);
	float viewscaleY = float (texSize.y / texSize.x);                 
    float numLayers = mix(maxLayers, minLayers, clamp(abs(V.z), 0.0, 1.0)); // clamp is required due to precision loss

    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;
    // depth of current layer
    float currentLayerDepth = 0.0;
	
	// parallax auto scale for non 1:1 (x,y) textures
	if (texSize.x > texSize.y)
	{
	parallaxScale = parallaxScale / float (texSize.y);
	}
	else //(texSize.x < texSize.y)
	{
	parallaxScale = parallaxScale / float (texSize.x);
	}	
	
	// correct the visual parallax effect for non 1:1 (x,y) ratio textures 
	if (texSize.x > texSize.y)
	{
	V.y = V.y / viewscaleX;
	}
	else
	{
	V.x = V.x / viewscaleY;
	}
			 
	// the amount to shift the texture coordinates per layer (from vector P)
    vec2 P = V.xy * parallaxScale;
    vec2 deltaTexCoords = P / numLayers; 
    vec2 currentTexCoords = PXcoord;									
    float currentDepthMapValue = GetDisplacementAt(currentTexCoords);
    while (currentLayerDepth < currentDepthMapValue)
    {
        // shift texture coordinates along direction of P
        currentTexCoords -= deltaTexCoords;

        // get depthmap value at current texture coordinates
        currentDepthMapValue = GetDisplacementAt(currentTexCoords);

        // get depth of next layer
        currentLayerDepth += layerDepth;
    }

	deltaTexCoords *= 0.5;
	layerDepth *= 0.5;

	currentTexCoords += deltaTexCoords;
	currentLayerDepth -= layerDepth;

	const int _reliefSteps = 8;
	int currentStep = _reliefSteps;
	while (currentStep > 0) {
	float currentGetDisplacementAt = GetDisplacementAt(currentTexCoords);
		deltaTexCoords *= 0.5;
		layerDepth *= 0.5;

		if (currentGetDisplacementAt > currentLayerDepth) {
			currentTexCoords -= deltaTexCoords;
			currentLayerDepth += layerDepth;
		}

		else {
			currentTexCoords += deltaTexCoords;
			currentLayerDepth -= layerDepth;
		}
		currentStep--;
	}

	return currentTexCoords;
}
