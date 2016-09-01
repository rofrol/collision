module Main exposing (main)

import Array
import String
import Html exposing (Html)
import Html.Attributes as Attr
import Html.App as App


-- Collision Library

import Collision
import Vector exposing (Vector)
import Quaternion exposing (Quaternion)
import Frame exposing (Frame)
import Face exposing (Face)


-- Project Local

import Types exposing (..)
import Controls
import OrthoView
import DataView
import Model


main : Program Never
main =
    App.beginnerProgram
        { model = init
        , update = update
        , view = view
        }


init : Model
init =
    { room = Entrance
    , red =
        { frame = Frame.identity
        , bounds = Collision.create cube
        , mesh = Model.drawable cube
        , selectedNode = ( 0, 0 )
        }
    , blue =
        { frame =
            { position = Vector.vector 0 1.6 -2
            , orientation =
                Quaternion.quaternion 0.85 0.35 0.35 0.15
                    |> Quaternion.scale (1.010101)
            }
        , bounds = Collision.create cube
        , mesh = Model.drawable cube
        , selectedNode = ( 0, 0 )
        }
    , collisionsOnly = False
    , showBoxes = False
    , treeLevel = 1
    }


cube : List Face
cube =
    Model.toFaces
        { vertexPositions =
            Array.fromList
                [ Vector.vector -1 1 1
                , Vector.vector 1 1 1
                , Vector.vector 1 -1 1
                , Vector.vector -1 -1 1
                , Vector.vector -1 1 -1
                , Vector.vector 1 1 -1
                , Vector.vector 1 -1 -1
                , Vector.vector -1 -1 -1
                ]
        , vertexIndexes =
            [ [ 3, 2, 1, 0 ]
            , [ 5, 4, 0, 1 ]
            , [ 6, 5, 1, 2 ]
            , [ 7, 6, 2, 3 ]
            , [ 7, 3, 0, 4 ]
            , [ 7, 4, 5, 6 ]
            ]
        }


update : Action -> Model -> Model
update action model =
    case ( action, model.room ) of
        --
        -- Navigate the UI
        --
        ( ChangeRoom room, _ ) ->
            { model | room = room }

        ( EditX xText, PositionEditor fields ) ->
            { model | room = PositionEditor { fields | xText = xText } }

        ( EditY yText, PositionEditor fields ) ->
            { model | room = PositionEditor { fields | yText = yText } }

        ( EditZ zText, PositionEditor fields ) ->
            { model | room = PositionEditor { fields | zText = zText } }

        ( EditAngle angleText, OrientationEditor fields ) ->
            { model
                | room =
                    OrientationEditor { fields | angleText = angleText }
            }

        ( SetAxis axis, OrientationEditor fields ) ->
            { model
                | room = OrientationEditor { fields | axis = axis }
            }

        --
        -- Move the entities
        --
        ( SetPosition, PositionEditor fields ) ->
            updateFrame
                (parseVector >> Frame.setPosition)
                fields
                model

        ( ExtrinsicNudge, PositionEditor fields ) ->
            updateFrame
                (parseVector >> Frame.extrinsicNudge)
                fields
                model

        ( IntrinsicNudge, PositionEditor fields ) ->
            updateFrame
                (parseVector >> Frame.intrinsicNudge)
                fields
                model

        ( ExtrinsicRotate, OrientationEditor fields ) ->
            updateFrame
                (parseRotation >> Frame.extrinsicRotate)
                fields
                model

        ( IntrinsicRotate, OrientationEditor fields ) ->
            updateFrame
                (parseRotation >> Frame.intrinsicRotate)
                fields
                model

        ( ResetOrientation, OrientationEditor fields ) ->
            updateFrame
                (\_ -> Frame.setOrientation Quaternion.identity)
                fields
                model

        --
        -- Change what information is displayed
        --
        ( SelectNode solid coords, _ ) ->
            updateEntity
                (\body -> { body | selectedNode = coords })
                solid
                model

        ( CollisionsOnly isChecked, _ ) ->
            { model | collisionsOnly = isChecked }

        ( ShowBoxes isChecked, _ ) ->
            { model | showBoxes = isChecked }

        ( SetTreeLevel treeLevel, _ ) ->
            { model | treeLevel = treeLevel }

        _ ->
            model


type alias WithSolid a =
    { a | solid : Solid }


updateFrame : (WithSolid a -> Frame -> Frame) -> WithSolid a -> Model -> Model
updateFrame transform fields model =
    updateEntity
        (\body ->
            { body | frame = transform fields body.frame }
        )
        fields.solid
        model


updateEntity : (Entity -> Entity) -> Solid -> Model -> Model
updateEntity transform solid model =
    case solid of
        Red ->
            { model | red = transform model.red }

        Blue ->
            { model | blue = transform model.blue }


parseVector : PositionFields -> Vector
parseVector fields =
    Vector.vector
        (toFloat fields.xText)
        (toFloat fields.yText)
        (toFloat fields.zText)


parseRotation : OrientationFields -> Quaternion
parseRotation fields =
    degrees (toFloat fields.angleText)
        |> Quaternion.fromAxisAngle fields.axis
        |> Maybe.withDefault Quaternion.identity


toFloat : String -> Float
toFloat text =
    String.toFloat text
        |> Result.withDefault 0


view : Model -> Html Action
view model =
    Html.div
        [ Attr.style
            [ ( "display", "flex" )
            , ( "flex-wrap", "wrap" )
            , ( "justify-content", "center" )
            ]
        ]
        [ Controls.draw model
        , OrthoView.draw model
        , DataView.draw model
        ]
