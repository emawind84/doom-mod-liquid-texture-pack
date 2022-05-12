mat3 GetTBN();
vec2 GetAutoscaleAt(vec2 texcoord);
vec2 ParallaxMap(mat3 tbn); 
vec3 GetBumpedNormal(mat3 tbn, vec2 parallaxMap);
vec2 GetTopdiffusescaleAt(vec2 parallaxMap);
vec2 GetbottomdiffusescaleAt(vec2 parallaxMap);
vec2 GetNormalLiquidscrollnegAt(vec2 parallaxMap);
vec2 GetLiquidscrollnegAt(vec2 parallaxMap);
vec2 GetLayerposAt(vec2 parallaxMap);

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
	vec2 ParallaxMap = ParallaxMap(tbn);
	
	////Masktexture////
	vec4 Diffusemask = texture(Diffusemask,GetLayerposAt(ParallaxMap));//parallax texture (black / white)
	
	////Normaltexture For bottom layer////
	vec4 normalmapbase = texture(Diffusedistortion, GetNormalLiquidscrollnegAt(ParallaxMap) * 0.35) * 0.2;
	
	////generate diffuse base texture////
	vec4 DiffuseyposM = texture(Diffuse, (normalmapbase.xy + GetLiquidscrollnegAt(ParallaxMap)))* 0.75;//diffuse texture scroll positive and brightness 
	vec4 DiffuseynegL = texture(Diffuse, (normalmapbase.xy + GetLiquidscrollnegAt(ParallaxMap)* 0.5))* 0.75;//diffuse texture scroll negetive and brightness 
	vec4 DiffuseyposXL = texture(Diffuse, (normalmapbase.xy + GetLiquidscrollnegAt(ParallaxMap) * 0.25))* 0.75;//diffuse texture scroll positive and brightness 
	vec4 Diffuse = clamp(DiffuseyposM + DiffuseynegL + DiffuseyposXL,0.0,1.0);//add diffuse textures togeter for generated effect
	
	////speculartexture////
	vec4 spectexture = texture(speculartexture, GetTopdiffusescaleAt(ParallaxMap));
	
	////generate diffuse top layer////
	vec4 Diffusetoplayer = spectexture;//top diffuse texture and scale value
	vec4 layerglow = vec4(0.35, 0.0, 0.0, 1.0);//RGBA
	vec4 Glowblend = clamp(layerglow * (clamp(Diffusemask * 40.0,0.0,1.0)) - (Diffusemask * 0.35),0.0,1.0);
	vec4 Diffusemasked = clamp(Diffuse - (clamp(Diffusemask * 40.0,0.0,1.0)),0.0,1.0);
	vec4 diffuselayermasked = Diffusetoplayer * (clamp(Diffusemask * 10.0,0.0,1.0));
	vec4 Diffusefinal = clamp(diffuselayermasked + Diffusemasked + Glowblend,0.0,1.0);
	
	//// generate brightmap texture////
	vec4 brightmapmask = clamp(Diffusefinal + 0.6 - (clamp(Diffusemask * 10.0,0.0,1.0)) + (clamp(Glowblend * 2.0,0.0,1.0)),0.0,1.0);
	
	////generate specular texure masked////
	vec4 Specfinal = spectexture * Diffusemask;//specular texture values multiplied by the diffuse mask texture ( 0.0 = black / 1.0 = white)

	////materials////
	material.Base = Diffusefinal;
    material.Normal = GetBumpedNormal(tbn, ParallaxMap);
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

vec2 GetNormalLiquidscrollnegAt(vec2 parallaxMap)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(parallaxMap);									
	vec2 offset = vec2(0,0);
	offset.y = texCoord.y + (-timer); //scroll direction and speed  
	offset.x = texCoord.x;
    return(texCoord += offset);
}

vec2 GetLiquidscrollnegAt(vec2 parallaxMap)//scroll direction for large base texture
{
	vec2 texcoord = GetbottomdiffusescaleAt(parallaxMap);									
	vec2 offset = vec2(0,0);
	const float pi = 3.14159265358979323846;
	//		Frequency         Animation Speed     Amplitude        
	//(sin(pi * 4.05 * (texcoord.x + timer * 0.15)) * 0.025)
	offset.y = texcoord.y + (timer * -0.6) + (sin(pi * 0.25 * (texcoord.x + timer * 0.01)) * 0.5) + (sin(pi * 4.5 * (texcoord.x + timer * 0.25)) * 0.1);
	offset.x = texcoord.x;
    return(texcoord += offset);
}

////////////////////////////////////////////////////////////////////////////////
/////////////////////Normal texture Generate and normal math ///////////////////
vec3 GetBumpedNormal(mat3 tbn, vec2 parallaxMap)
{
#if defined(NORMALMAP)
	vec3 Diffusemask = (texture(Diffusemask, GetLayerposAt(parallaxMap)) * 0.5).xyz;//parallax texture (black / white)
	vec3 layermasknormal = (texture(layermasknormal, GetLayerposAt(parallaxMap)) * 0.5).xyz;//normalmap for Diffusemask mask based on parallax map
	vec3 normalmap = texture(normaltexture, GetTopdiffusescaleAt(parallaxMap)).xyz;//normalmap for diffuse top layer texture
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
vec2 GetLayerposAt(vec2 parallaxMap)
{  	
	vec2 texcoord = parallaxMap;
	texcoord.x = texcoord.x * 1.35;
	texcoord.y = texcoord.y * 0.2;
	vec2 offset = vec2(0,0);		
	const float pi = 3.14159265358979323846;	
	//		Frequency         Animation Speed     Amplitude        
	//(sin(pi * 4.05 * (texcoord.x + timer * 0.15)) * 0.025)
	offset.y = texcoord.y + (timer * -0.16) + (sin(pi * 0.25 * (texcoord.x + timer * 0.01)) * 0.5) + (sin(pi * 4.5 * (texcoord.x + timer * 0.15)) * 0.025);                   
	offset.x = texcoord.x + timer * 0.005;
	texcoord += offset;
    return texcoord;													
}																						

////////////////////////////////////////////////////////////////////////////////
///////////////top layer diffuse texture scale//////////////////////////////////
vec2 GetTopdiffusescaleAt(vec2 parallaxMap)
{																		
    vec2 texcoord = GetLayerposAt(parallaxMap);
	texcoord.x = texcoord.x * 7.0;
	texcoord.y = texcoord.y * 10.0;
    return texcoord;
}

////////////////////////////////////////////////////////////////////////////////
///////////////bottom diffuse texture scale/////////////////////////////////////
vec2 GetbottomdiffusescaleAt(vec2 parallaxMap)
{		
	vec2 texcoord = parallaxMap;
	texcoord.x = texcoord.x * 4.0;
	texcoord.y = texcoord.y;
    return texcoord;
}

////////////////////////////////////////////////////////////////////////////////
/////////////////main parallax texture scale and texcoord setup/////////////////
vec2 GetAutoscaleAt(vec2 currentTexCoords) //////sets the main parallax texture scale size which all the other texture scale values are based on.
{
	vec2 PXCoord = vTexCoord.st;
	PXCoord.x = PXCoord.x * 0.375;//scale main parallax texcoord here
	PXCoord.y = PXCoord.y * 0.375;//scale main parallax texcoord here 													
    return PXCoord;
}

////////////////////////////////////////////////////////////////////////////////
///////////////////Parallax texture color setup/////////////////////////////////
float GetDisplacementAt(vec2 currentTexCoords)
{
	vec2 texCoord = vTexCoord.st;
	vec2 PXcoord = GetAutoscaleAt(currentTexCoords).xy;
	vec2 offset = vec2(0,0);
	offset.y =  PXcoord.y * 0.75 + timer * -0.45; //displacement texture scroll direction and speed
	offset.x =  PXcoord.x + (timer * 0.025); //displacement texture scroll direction and speed
	float parallax = texture(Parallax, offset).r;//main parallax texture with adjusted texture offset
    return 1.0 - (parallax);
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
	vec2 parallaxScale = vec2(10.0);
	float minLayers = 0.0;
    float maxLayers = 1.0;
	float viewscale = 0.0;
	float viewscaleX = float (texSize.x / texSize.y);
	float viewscaleY = float (texSize.y / texSize.x);                 
    float numLayers = mix(minLayers, maxLayers, clamp(abs(V.z), 0.0, 1.0)); // clamp is required due to precision loss

    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;
    // depth of current layer
    float currentLayerDepth = 0.0;
	
	// parallax auto scale for non 1:1 (x,y) textures
	parallaxScale = parallaxScale / float (max(texSize.y, texSize.x));
	
	// correct the visual parallax effect for non 1:1 (x,y) ratio textures 
	V.y = V.y / max(viewscaleX, viewscaleY);
			 
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
