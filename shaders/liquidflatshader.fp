mat3 GetTBN();
vec2 GetAutoscaleAt(vec2 texcoord);
vec2 ParallaxMap(mat3 tbn); 
vec2 GetbottomdiffusescaleAt(vec2 parallaxMap);
vec2 GetLiquidAnimationYposAt(vec2 parallaxMap);
vec2 GetLiquidAnimationYnegAt(vec2 parallaxMap);
vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord);


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
    vec2 texCoord = ParallaxMap(tbn);//parallax texture coord

	//// generate normal texture
	vec4 NMone = texture(normaltexture, GetLiquidAnimationYposAt(texCoord));//normalmap scroll Y positive + devide textures brightness in half
	vec4 NM2two = texture(normaltexture, GetLiquidAnimationYnegAt(texCoord));//normalmap scroll y negetive + devide textures brightness in half
	vec2 Nmap = ((NMone + NM2two) * 0.5).xy;//add together as one texture at full brightness.
	vec2 Nmap2 = -Nmap * 0.5;
	
	////color tint values///////////
	////water
	#if defined (WATER)
	vec4 refacttint = vec4(0.0, 1.0, 0.75, 1.0);//RGBA fake refaction color
	vec4 reflectioncolor = vec4(0.18, 0.25, 0.30, 1.0);//RGBA reflectioncolor color
	#else
		////////blood
		#if defined (BLOOD)
		vec4 refacttint = vec4(1.0, 0.0, 0.0, 1.0);//RGBA fake refaction color
		vec4 reflectioncolor = vec4(0.30, 0.14, 0.10, 1.0);//RGBA reflectioncolor color
		#else
			////////slime
			#if defined (SLIME)
			vec4 refacttint = vec4(1.0, 0.80, 0.0, 1.0);//RGBA fake refaction color
			vec4 reflectioncolor = vec4(0.30, 0.26, 0.15, 1.0);//RGBA reflectioncolor color
			#endif
		#endif
	#endif
	
	////generate reflection
	vec4 Enviro = texture(reflection, (normalize(transpose(tbn) * (uCameraPos.xyz - pixelpos.xyz)).xy) + (Nmap * 0.30));//reflection texture interat with generated normal texture
	vec4 ReflectionVec4 = clamp(Enviro * reflectioncolor,0.0,1.0);//combine rendered reflection with color tint rgb values
	
	////generate diffuse texture
	vec4 DIffuseypos = texture(Diffuse, ( Nmap2 + GetLiquidAnimationYposAt(texCoord)) * 0.4);//diffuse texture scroll Y positive	and devide brightness in half
	vec4 DIffuseyneg = texture(Diffuse, ( Nmap2 + GetLiquidAnimationYnegAt(texCoord)) * 0.4);//diffuse texture scroll y negetive and devide brightness in half
	vec4 DIffuselarge = (DIffuseypos + DIffuseyneg) * 0.25;
	////refact diffuse color
	vec4 refractypos = texture(Diffuse, (-Nmap + GetLiquidAnimationYposAt(texCoord)));
	vec4 refractyneg = texture(Diffuse, (-Nmap + GetLiquidAnimationYnegAt(texCoord)));
	vec4 refaction = (refractypos + refractyneg) * 0.25 * refacttint;
	vec4 DiffuseVec4 = clamp(DIffuselarge + refaction + ReflectionVec4,0.0,1.0);//add both diffuse textures and refaction togeter for generated scrolling effect at full brightness.
	
	material.Base = DiffuseVec4; //generated reflection and diffuse texture	combine together for final result
    material.Normal = GetBumpedNormal(tbn, texCoord);
	material.Bright = texture(brighttexture, texCoord); 
#if defined(SPECULAR)
    material.Specular = texture(speculartexture, texCoord).rgb;
    material.Glossiness = uSpecularMaterial.x;
    material.SpecularLevel = uSpecularMaterial.y;
#endif
	return material;
}


// Tangent/bitangent/normal space to world space transform matrix
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
//////////////////////////////animate liquid movement///////////////////////////

vec2 GetLiquidAnimationYposAt(vec2 parallaxMap)
{
	vec2 texCoord = GetbottomdiffusescaleAt(parallaxMap);
	const float pi = 3.14159265358979323846;									
	vec2 offset = vec2(0,0);
	offset.y = texCoord.y * 1.5 + (timer * 0.11);//offset texture by 50% + scroll direction and speed to correct unwanted visual texture overlapping animation glitch
	offset.x = texCoord.x * 1.5;//offset texture by 50% + scroll direction and speed to correct unwanted visual texture overlapping animation glitch                																			
    return(texCoord += offset);
}

vec2 GetLiquidAnimationYnegAt(vec2 parallaxMap)
{
	vec2 texCoord = GetbottomdiffusescaleAt(parallaxMap);
	const float pi = 3.14159265358979323846;									
	vec2 offset = vec2(0,0);
	offset.y =  texCoord.y + (timer * -0.11);//scroll direction and speed  
	offset.x = texCoord.x;
    return(texCoord += offset);
}
////////////////////////////////////////////////////////////////////////////////
/////////////////////Normal texture Generate and normal math ///////////////////

vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord)
{
#if defined(NORMALMAP)
	vec3 normalmapA = texture(normaltexture, GetLiquidAnimationYposAt(texcoord)).xyz;//normalmap Y+ offset texture scroll + devide textures brightness in half
	vec3 normalmapB = texture(normaltexture, GetLiquidAnimationYnegAt(texcoord)).xyz;//normalmap Y- offset texture scroll + devide textures brightness in half
	vec3 normalmap = (normalmapA + normalmapB) * 0.5;//combine as one full texture brightness
    normalmap = normalmap * 255./127. - 128./127.; // Math so "odd" because 0.5 cannot be precisely described in an unsigned format
    normalmap.xy *= vec2(0.5, -0.5); //flip Y
    return normalize(tbn * normalmap);
#else
    return normalize(vWorldNormal.xyz);
#endif
}

////////////////////////////////////////////////////////////////////////////////
///////////////bottom diffuse texture scale/////////////////////////////////////
vec2 GetbottomdiffusescaleAt(vec2 parallaxMap)
{																			
    return parallaxMap * 1.2;//change scale of bottom diffuse texture here
}

////////////////////////////////////////////////////////////////////////////////
/////////////////main parallax and material base texcoord setup/////////////////
vec2 GetAutoscaleAt(vec2 currentTexCoords) //////sets the canvas base scale and texcoord which all the textures are applied to such as diffuse / parallax / normalmap etc.
{
	vec2 PXCoord = vTexCoord.st;
	PXCoord.x = PXCoord.x * 0.2;//scale main parallax texture here
	PXCoord.y = PXCoord.y * 0.2;//scale main parallax texture here 
	vec2 offset = vec2(0,0);
	const float pi = 3.14159265358979323846;
	//		Frequency         Animation Speed     Amplitude        
	//(sin(pi * 4.05 * (texcoord.x + (timer * 0.15))) * 0.025)
	offset.y = sin(pi * (PXCoord.x + (timer * 0.075))) * 0.03;                     
	offset.x = sin(pi * (PXCoord.y + (timer * 0.075))) * 0.03;
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
	offset.y =  PXcoord.y + (timer * 0.25); //parallax texture scroll direction and speed
	offset.x =  PXcoord.x + (timer * 0.01); //parallax texture scroll direction and speed
	float parallax = texture(Parallax, offset).r;//parallax texture with adjusted texture offset
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
	vec2 parallaxScale = vec2(5.0);
	float minLayers = 4.0;
    float maxLayers = 8.0;
	float viewscale = 0.0;
	float viewscaleX = float (texSize.x / texSize.y);
	float viewscaleY = float (texSize.y / texSize.x);                 
    float numLayers = mix(maxLayers, minLayers, clamp(abs(V.z), 0.0, 1.0)); // clamp is required due to precision loss

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

	const int _reliefSteps = 4;
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
