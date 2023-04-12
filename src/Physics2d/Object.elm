module Physics2d.Object exposing
    ( Object
    , fromPolygon, fromCircle
    , position, setPosition
    , velocity, setVelocity, addVelocity
    , heading, setHeading
    , angularSpeed, setAngularSpeed
    , integrate
    , areColliding
    , ShapeView(..)
    , view, View
    )

{-|

@docs Object


# Constructors

@docs fromPolygon, fromCircle


# Motion


## Linear

@docs position, setPosition
@docs velocity, setVelocity, addVelocity


## Angular

@docs heading, setHeading
@docs angularSpeed, setAngularSpeed


# Integration

@docs integrate


# Collision

@docs areColliding


# View

@docs ShapeView
@docs view, View

-}

import Angle
import AngularSpeed
import Direction2d
import Length
import Physics2d.Circle
import Physics2d.CoordinateSystem exposing (TopLeft)
import Physics2d.Polygon
import Physics2d.Time
import Point2d
import Quantity
import Speed
import Vector2d


type Object
    = Object Internals


type Shape
    = PolygonShape Physics2d.Polygon.Polygon
    | CircleShape Physics2d.Circle.Circle


type alias Internals =
    { shape : Shape
    , position : Point2d.Point2d Length.Meters TopLeft
    , positionPrevious : Point2d.Point2d Length.Meters TopLeft
    , heading : Direction2d.Direction2d TopLeft
    , headingPrevious : Direction2d.Direction2d TopLeft
    }


areColliding : Object -> Object -> Bool
areColliding (Object internals1) (Object internals2) =
    case ( internals1.shape, internals2.shape ) of
        ( CircleShape circle1, CircleShape circle2 ) ->
            let
                distanceBetweenCenters =
                    Point2d.distanceFrom
                        internals1.position
                        internals2.position

                radiusSum =
                    Quantity.sum
                        [ Physics2d.Circle.radius circle1
                        , Physics2d.Circle.radius circle2
                        ]
            in
            Quantity.lessThanOrEqualTo radiusSum distanceBetweenCenters

        _ ->
            False


fromPolygon :
    { position : Point2d.Point2d Length.Meters TopLeft
    , polygon : Physics2d.Polygon.Polygon
    }
    -> Object
fromPolygon config =
    initialInternals
        { position = config.position
        , heading = Direction2d.fromAngle (Angle.turns 0)
        }
        (PolygonShape config.polygon)
        |> Object


fromCircle :
    { position : Point2d.Point2d Length.Meters TopLeft
    , radius : Length.Length
    }
    -> Object
fromCircle config =
    initialInternals
        { position = config.position
        , heading = Direction2d.fromAngle (Angle.turns 0)
        }
        (CircleShape
            (Physics2d.Circle.new
                { radius = config.radius }
            )
        )
        |> Object


initialInternals :
    { position : Point2d.Point2d Length.Meters TopLeft
    , heading : Direction2d.Direction2d TopLeft
    }
    -> shape
    ->
        { position : Point2d.Point2d Length.Meters TopLeft
        , positionPrevious : Point2d.Point2d Length.Meters TopLeft
        , heading : Direction2d.Direction2d TopLeft
        , headingPrevious : Direction2d.Direction2d TopLeft
        , shape : shape
        }
initialInternals config shape =
    { position = config.position
    , positionPrevious = config.position
    , heading = config.heading
    , headingPrevious = config.heading
    , shape = shape
    }


position : Object -> Point2d.Point2d Length.Meters TopLeft
position (Object internals) =
    internals.position


setPosition : Point2d.Point2d Length.Meters TopLeft -> Object -> Object
setPosition newPosition (Object internals) =
    let
        displacementToPrevious =
            Vector2d.from internals.position internals.positionPrevious
    in
    Object
        { internals
            | position = newPosition
            , positionPrevious =
                newPosition
                    |> Point2d.translateBy displacementToPrevious
        }


velocity : Object -> Vector2d.Vector2d Speed.MetersPerSecond TopLeft
velocity (Object internals) =
    Vector2d.from internals.positionPrevious internals.position
        |> Vector2d.per Physics2d.Time.step


setVelocity :
    Vector2d.Vector2d Speed.MetersPerSecond TopLeft
    -> Object
    -> Object
setVelocity newVelocity (Object internals) =
    let
        displacement : Vector2d.Vector2d Length.Meters TopLeft
        displacement =
            Vector2d.reverse newVelocity
                |> Vector2d.for Physics2d.Time.step
    in
    Object
        { internals
            | positionPrevious =
                internals.position
                    |> Point2d.translateBy displacement
        }


addVelocity :
    Vector2d.Vector2d Speed.MetersPerSecond TopLeft
    -> Object
    -> Object
addVelocity velocityToAdd (Object internals) =
    let
        displacement : Vector2d.Vector2d Length.Meters TopLeft
        displacement =
            Vector2d.reverse velocityToAdd
                |> Vector2d.for Physics2d.Time.step
    in
    Object
        { internals
            | positionPrevious =
                internals.positionPrevious
                    |> Point2d.translateBy displacement
        }


heading : Object -> Direction2d.Direction2d TopLeft
heading (Object internals) =
    internals.heading


setHeading : Direction2d.Direction2d TopLeft -> Object -> Object
setHeading newHeading (Object internals) =
    Object
        { internals
            | heading = newHeading
            , headingPrevious = newHeading
        }


angularSpeed : Object -> AngularSpeed.AngularSpeed
angularSpeed (Object internals) =
    Direction2d.angleFrom internals.headingPrevious internals.heading
        |> Quantity.per Physics2d.Time.step


setAngularSpeed : AngularSpeed.AngularSpeed -> Object -> Object
setAngularSpeed newAngularSpeed (Object internals) =
    let
        headingStep =
            newAngularSpeed
                |> Quantity.for Physics2d.Time.step

        updatedHeadingPrevious =
            internals.heading
                |> Direction2d.rotateBy
                    (Quantity.negate headingStep)
    in
    Object
        { internals
            | headingPrevious = updatedHeadingPrevious
        }


integrate : Object -> Object
integrate (Object internals) =
    let
        headingStep : Angle.Angle
        headingStep =
            angularSpeed (Object internals)
                |> Quantity.for Physics2d.Time.step

        positionStep : Vector2d.Vector2d Length.Meters TopLeft
        positionStep =
            Vector2d.from internals.positionPrevious internals.position
    in
    Object
        { internals
            | heading =
                internals.heading
                    |> Direction2d.rotateBy headingStep
            , headingPrevious =
                internals.heading
            , position =
                internals.position
                    |> Point2d.translateBy positionStep
            , positionPrevious =
                internals.position
        }


type alias View =
    { position : Point2d.Point2d Length.Meters TopLeft
    , heading : Angle.Angle
    , shape : ShapeView
    }


type ShapeView
    = PolygonShapeView
        { vertices : List (Point2d.Point2d Length.Meters TopLeft)
        }
    | CircleShapeView
        { radius : Length.Length
        , position : Point2d.Point2d Length.Meters TopLeft
        }


view : Object -> View
view (Object internals) =
    { position = internals.position
    , heading = Direction2d.toAngle internals.heading
    , shape = toShapeView internals
    }


toShapeView : Internals -> ShapeView
toShapeView internals =
    case internals.shape of
        PolygonShape polygon ->
            PolygonShapeView
                { vertices =
                    Physics2d.Polygon.toPoints polygon
                        |> List.map
                            (Point2d.rotateAround
                                Point2d.origin
                                (internals.heading
                                    |> Direction2d.toAngle
                                )
                            )
                        |> List.map
                            (Point2d.translateBy
                                (Vector2d.from
                                    Point2d.origin
                                    internals.position
                                )
                            )
                }

        CircleShape circle ->
            CircleShapeView
                { radius = Physics2d.Circle.radius circle
                , position = internals.position
                }
