mat3 GetTBN();
vec2 GetAutoscaleAt(vec2 texcoord); 
vec2 ParallaxMap(mat3 tbn); 
vec3 GetBumpedNormal(mat3 tbn, vec2 parallaxMap);
vec2 GetTopdiffusescaleAt(vec2 parallaxMap);
vec2 GetbottomdiffusescaleAt(vec2 parallaxMap);
vec2 GetNormalLiquidscrollposAt(vec2 parallaxMap);
vec2 GetNormalLiquidscrollnegAt(vec2 parallaxMap);
vec2 GetLiquidscrollposAt(vec2 parallaxMap);
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
	vec4 Diffusemasktex = texture(Diffusemask, GetLayerposAt(ParallaxMap));//parallax texture (black / white)
	
	////Normaltexture For top layer////
	vec4 Layernormal = texture(layermasknormal, GetLayerposAt(ParallaxMap));//normalmap for Diffusemasktex mask based on parallax map
	vec4 Normalmap = texture(normaltexture, GetTopdiffusescaleAt(ParallaxMap));//normalmap for diffuse top layer texture
	vec4 Normalmapslime = (Layernormal + Normalmap) * 0.5;
	
	////Normaltexture For bottom layer////
	vec4 NormalmapA = texture(normaltexture, GetNormalLiquidscrollposAt(ParallaxMap)) * 0.25;
	vec4 NormalmapB = texture(normaltexture, GetNormalLiquidscrollnegAt(ParallaxMap)) * 0.25;
	vec4 Normalmapbase = NormalmapA + NormalmapB;
	
	////generate diffuse base texture
	vec4 DiffuseyposL = texture(Diffuse, (Normalmapbase.xy + GetLiquidscrollposAt(ParallaxMap)) * 0.25);//diffuse texture scroll positive and brightness 
	vec4 DiffuseynegL = texture(Diffuse, (-Normalmapbase.xy + GetLiquidscrollnegAt(ParallaxMap)) * 0.25);//diffuse texture scroll negetive and brightness 
	vec4 DiffuseyposXL = texture(Diffuse, (Normalmapbase.xy + GetLiquidscrollposAt(ParallaxMap)) * 0.11);//diffuse texture scroll positive and brightness 
	vec4 DiffuseynegXL = texture(Diffuse, (-Normalmapbase.xy + GetLiquidscrollnegAt(ParallaxMap)) * 0.11);//diffuse texture scroll negetive and brightness 
	vec4 DiffuseglowyposXL = texture(Diffuse, (-Normalmapslime.xy + GetLiquidscrollposAt(ParallaxMap)) * 0.25);//glow texture scroll positive and brightness 
	vec4 DiffuseglowynegXL = texture(Diffuse, (-Normalmapslime.xy + GetLiquidscrollnegAt(ParallaxMap)) * 0.11);//glow texture scroll negetive and brightness 
	vec4 Diffusebase = clamp(DiffuseyposL + DiffuseynegL + DiffuseyposXL + DiffuseynegXL,0.0,1.0);//add diffuse textures togeter for generated effect
	
	////speculartexture////
	vec4 Spectexture = texture(speculartexture, GetTopdiffusescaleAt(ParallaxMap));
	
	////generate diffuse top layer////
	vec4 Diffusetoplayer = Spectexture * clamp(Diffusemasktex * 100.0,0.0,1.0);//top diffuse texture and scale value
	vec4 UnderGlowblend = clamp(DiffuseglowyposXL + DiffuseglowynegXL * 0.5,0.0,1.0) * Diffusemasktex;//slime glow
	vec4 Diffusemasked = clamp(Diffusebase - (clamp(Diffusemasktex * 15.0,0.0,1.0)),0.0,1.0);
	
	////generate reflection////
	vec4 Reflectionbase = texture(reflection, (normalize(transpose(tbn) * (uCameraPos.xyz - pixelpos.xyz)).xy) + (Normalmapslime.xy));//reflection texture used for fake surface reflection 
	vec4 Reflectionfianl = Reflectionbase * clamp(Diffusetoplayer * Diffusemasktex * 5.0,0.0,1.0);
	
	////diffues final////
	vec4 Diffuselayermasked = clamp(UnderGlowblend + (Diffusetoplayer * 0.5) + Reflectionfianl * (clamp(Diffusemasktex,0.0,1.0)),0.0,1.0);
	vec4 Diffusefinal = clamp(Diffuselayermasked + Diffusemasked,0.0,1.0);
	
	//// generate brightmap texture////
	vec4 Brightmapmask = clamp(Diffusefinal + 0.6 - (clamp(Diffusemasktex * 20.0,0.0,1.0)) + (clamp(Diffusetoplayer * 8.0 + UnderGlowblend,0.0,1.0)),0.0,1.0);
	
	////generate specular texure masked////
	vec4 Specbasecolor = vec4(0.25, 0.35, 0.15, 1.0);//RGBA Specbaselayercolor color
	vec4 Spectopcolor = vec4(0.20, 0.27, 0.13, 1.0);//RGBA Spectoplayercolor color
	vec4 Specbase = clamp((Spectexture * 0.0 + Specbasecolor) - clamp(Diffusemasktex * 5.0,0.0,1.0),0.0,1.0);
	vec4 Specfinal = clamp((Spectexture * 0.0 + Spectopcolor) * clamp(Diffusemasktex * 5.0,0.0,1.0) + Specbase,0.0,1.0);;//specular texture values multiplied by the diffuse mask texture ( 0.0 = black / 1.0 = white)

	////materials////
	material.Base = Diffusefinal;
    material.Normal = GetBumpedNormal(tbn, ParallaxMap);
	material.Bright = Brightmapmask; 
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

vec2 GetNormalLiquidscrollposAt(vec2 parallaxMap)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(parallaxMap);							
	vec2 offset = vec2(0,0);
	offset.x = texCoord.x * 1.5 + (timer * 0.12); //scroll direction and speed    
	offset.y = texCoord.y * 1.5;   
    return(texCoord += offset);
}

vec2 GetNormalLiquidscrollnegAt(vec2 parallaxMap)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(parallaxMap);									
	vec2 offset = vec2(0,0);
	offset.x = texCoord.x + (timer * -0.12); //scroll direction and speed  
	offset.y = texCoord.y;
    return(texCoord += offset);
}

vec2 GetLiquidscrollposAt(vec2 parallaxMap)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(parallaxMap);							
	vec2 offset = vec2(0,0);
	offset.y = texCoord.y * 1.5 + (timer * 0.3); //scroll direction and speed     
	offset.x = texCoord.x * 1.5;  
    return(texCoord += offset);
}

vec2 GetLiquidscrollnegAt(vec2 parallaxMap)//scroll direction for large base texture
{
	vec2 texCoord = GetbottomdiffusescaleAt(parallaxMap);									
	vec2 offset = vec2(0,0);
	offset.y = texCoord.y + (timer * -0.3); //scroll direction and speed  
	offset.x = texCoord.x;
    return(texCoord += offset);
}

////////////////////////////////////////////////////////////////////////////////
/////////////////////Normal texture Generate and normal math ///////////////////
vec3 GetBumpedNormal(mat3 tbn, vec2 parallaxMap)
{
#if defined(NORMALMAP)
	//normalmap top layer
	vec3 Diffusemasktex = (texture(Diffusemask,GetLayerposAt(parallaxMap))).xyz;//parallax texture (black / white)
	vec3 Toplayernormal = (texture(layermasknormal, GetLayerposAt(parallaxMap)) * 0.45).xyz;//normalmap for Diffusemask mask based on parallax map
	vec3 Normalmap = (texture(normaltexture, GetTopdiffusescaleAt(parallaxMap))* 0.55).xyz;//normalmap for diffuse top layer texture
	vec3 Normalmapmaksed = (Normalmap + Toplayernormal) * clamp(Diffusemasktex * 10.0,0.0,1.0);//remove diffuse normalmap color based on layermask brightness
	//normalmap bottom layer
	vec3 NormalmapA = (texture(normaltexture, GetNormalLiquidscrollposAt(parallaxMap))).xyz;
	vec3 NormalmapB = (texture(normaltexture, GetNormalLiquidscrollnegAt(parallaxMap))).xyz;
	vec3 Normalmapbase = clamp((NormalmapA + NormalmapB) * 0.5 - clamp(Diffusemasktex * 10.0,0.0,1.0),0.0,1.0);
	//normalmap combined
	vec3 Normalcombined = clamp(Normalmapmaksed + Normalmapbase,0.0,1.0);//add the adjusted diffuse normal map color to the layermask normal map color
		 Normalcombined = Normalcombined * 255./127. - 128./127.; // Math so "odd" because 0.5 cannot be precisely described in an unsigned format
		 Normalcombined.xy *= vec2(0.5, -0.5); // flip Y
    return normalize(tbn * Normalcombined);
#else
    return normalize(vWorldNormal.xyz);
#endif
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////layer mask texture scale////////////////////////////////
vec2 GetLayerposAt(vec2 parallaxMap)
{        																				
    return parallaxMap * 0.75;//change scale of layer mask texture here  -----------------															
}																							//
float GetLayerscaleAt(vec2 currentTexCoords)												//numbers must match
{																							//
    return 0.75;//change scale of Layer mask texture here -------------------------------------
}

////////////////////////////////////////////////////////////////////////////////
///////////////top layer diffuse texture scale//////////////////////////////////
vec2 GetTopdiffusescaleAt(vec2 parallaxMap)
{																		
    return parallaxMap * 12.5;//change scale of top diffuse texture here 
}

////////////////////////////////////////////////////////////////////////////////
///////////////bottom diffuse texture scale/////////////////////////////////////
vec2 GetbottomdiffusescaleAt(vec2 parallaxMap)
{																			
    return parallaxMap * 5.0;//change scale of bottom diffuse texture here
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
	//(sin(pi * 4.05 * (texcoord.x + (timer * 0.15))) * 0.025)
	offset.y = sin(pi * (PXCoord.x + (timer * 0.05))) * 0.05;                     
	offset.x = sin(pi * (PXCoord.y + (timer * 0.05))) * 0.05;
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
	offset.y =  PXcoord.y + (timer * 0.3); //parallax texture scroll direction and speed
	offset.x =  PXcoord.x + (timer * 0.025); //parallax texture scroll direction and speed
	float parallax = texture(Parallax, offset).r;//main parallax texture with adjusted texture offset
	float Diffusemask = texture(Diffusemask, (PXcoord * GetLayerscaleAt(currentTexCoords))).r;//top layer parallax texture 
	float parallaxwave = clamp(parallax,0.0,1.0);//clamp used to keep values between 0 and 1
	float parallaxcombined = clamp(parallaxwave + (Diffusemask * 0.25),0.0,1.0);//blend texture brightness and keep values between 0 and 1
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
