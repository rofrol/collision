module OrthoView exposing (draw)

import Html exposing (Html)
import Html.Attributes as Attr
import WebGL exposing (Drawable(..), Shader, Renderable)
import Math.Vector3 as Vec3 exposing (Vec3)
import Math.Vector4 as Vec4 exposing (Vec4)
import Math.Matrix4 as Mat4 exposing (Mat4)
import Frame exposing (Frame)
import Vector


-- Project Local

import Types exposing (..)
import Mesh


draw : Model -> Html a
draw model =
    let
        bkgColor =
            if model.collision then
                "#f0ffd0"
            else
                "#d0f0ff"
    in
        Html.div [ Attr.style [ ( "height", "500" ) ] ]
            [ WebGL.toHtml
                [ Attr.width 500
                , Attr.height 500
                , Attr.style [ ( "background-color", bkgColor ) ]
                ]
                [ drawSolid model Red model.red
                , drawSolid model Blue model.blue
                , drawAxes
                ]
            ]


mesh : Model -> Entity -> Drawable Vertex
mesh settings entity =
    let
        depth =
            if settings.showBoxes then
                settings.treeLevel
            else
                -- arbitrary big number
                100
    in
        if settings.collisionsOnly then
            Mesh.whitelistedBoxes entity.hits depth entity.bounds
        else
            Mesh.boxes depth entity.bounds


drawSolid : Model -> Solid -> Entity -> Renderable
drawSolid model solid entity =
    let
        color =
            case solid of
                Red ->
                    Vec3.vec3 1 0 0

                Blue ->
                    Vec3.vec3 0 0 1
    in
        WebGL.render vertexShader
            fragmentShader
            (mesh model entity)
            (uniform color entity.frame)


drawAxes : Renderable
drawAxes =
    let
        vert x y z =
            { position = Vec3.vec3 x y z }

        mesh =
            Lines
                [ -- X
                  ( vert 100 0 0, vert -100 0 0 )
                , ( vert 10 -0.2 0.2, vert 10 -0.8 0.8 )
                , ( vert 10 -0.2 0.8, vert 10 -0.8 0.2 )
                  -- Y
                , ( vert 0 100 0, vert 0 -100 0 )
                , ( vert 0.1 10 -0.5, vert 0.5 10 -0.5 )
                , ( vert 0.5 10 -0.9, vert 0.5 10 -0.5 )
                , ( vert 0.9 10 -0.1, vert 0.5 10 -0.5 )
                  -- Z
                , ( vert 0 0 100, vert 0 0 -100 )
                , ( vert -0.8 0.8 10, vert -0.2 0.8 10 )
                , ( vert -0.2 0.8 10, vert -0.8 0.2 10 )
                , ( vert -0.8 0.2 10, vert -0.2 0.2 10 )
                ]
    in
        uniform (Vec3.vec3 0.5 0.5 0.5) Frame.identity
            |> WebGL.render axisVertexShader axisFragmentShader mesh


uniform : Vec3 -> Frame -> Uniform
uniform color frame =
    let
        cameraPosition =
            Vector.vector 5 5 5

        cameraOrientation =
            Mat4.makeRotate (turns 0.125) (Vec3.vec3 1 0 0)
                |> Mat4.rotate (turns -0.125) (Vec3.vec3 0 1 0)

        placement =
            Frame.toMat4 frame
    in
        { cameraPosition = Vec3.fromRecord cameraPosition
        , cameraOrientation = cameraOrientation
        , perspective = Mat4.makeOrtho -10 10 -10 10 -100 100
        , placement = placement
        , inversePlacement = Mat4.inverseOrthonormal placement
        , diffuseColor = color
        }


type alias Uniform =
    { cameraPosition : Vec3
    , perspective : Mat4
    , cameraOrientation : Mat4
    , placement : Mat4
    , inversePlacement : Mat4
    , diffuseColor : Vec3
    }


type alias Varying =
    { nonspecularColor : Vec3
    , specularFactor : Float
    }


vertexShader : Shader Vertex Uniform Varying
vertexShader =
    [glsl|
         precision mediump float;

         attribute vec3 position;
         attribute vec3 normal;

         uniform vec3 cameraPosition;
         uniform mat4 cameraOrientation;
         uniform mat4 perspective;
         uniform mat4 placement;
         uniform mat4 inversePlacement;
         uniform vec3 diffuseColor;

         varying vec3 nonspecularColor;
         varying float specularFactor;

         void main() {
             // Vertex Positioning

             vec4 worldFrame = placement * vec4(position, 1);
             vec4 cameraOffset = worldFrame - vec4(cameraPosition, 0);
             gl_Position = perspective * cameraOrientation * cameraOffset;


             // Lighting
             vec3 ambientColor = vec3(0.1, 0.1, 0.1);
             vec3 lightDirection = normalize(vec3(1, 1.5, 2));

             vec3 surfaceNormal = vec3(vec4(normal, 0) * inversePlacement);
             float diffuseFactor = dot(lightDirection, surfaceNormal);
             nonspecularColor = ambientColor + diffuseColor * diffuseFactor;

             vec3 reflection = normalize(2.0 * diffuseFactor * surfaceNormal - lightDirection);
             vec3 cameraDirection = normalize(-cameraOffset.xyz);
             specularFactor = clamp(dot(reflection, cameraDirection), 0.0, 1.0);
         }
    |]


fragmentShader : Shader {} Uniform Varying
fragmentShader =
    [glsl|
        precision mediump float;

        varying vec3 nonspecularColor;
        varying float specularFactor;

        void main() {
            float shininess = 3.0;
            vec3 baseSpecColor = vec3(1, 1, 1);

            vec3 specularColor = baseSpecColor * pow(specularFactor, shininess);

            gl_FragColor = vec4(nonspecularColor + specularColor, 1);
        }
    |]


axisVertexShader : Shader { position : Vec3 } Uniform { color : Vec4 }
axisVertexShader =
    [glsl|
         precision mediump float;

         attribute vec3 position;

         uniform vec3 cameraPosition;
         uniform mat4 cameraOrientation;
         uniform mat4 perspective;
         uniform mat4 placement;
         uniform vec3 diffuseColor;

         varying vec4 color;

         void main() {
             vec4 worldFrame = placement * vec4(position, 1);
             vec4 cameraOffset = worldFrame - vec4(cameraPosition, 0);
             gl_Position = perspective * cameraOrientation * cameraOffset;

             color = vec4(diffuseColor, 1);
         }
    |]


axisFragmentShader : Shader {} Uniform { color : Vec4 }
axisFragmentShader =
    [glsl|
         precision mediump float;

         varying vec4 color;

         void main() {
             gl_FragColor = color;
         }
    |]
