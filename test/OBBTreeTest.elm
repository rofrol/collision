module OBBTreeTest exposing (testSuite)

import ElmTest exposing (..)
import Json.Decode as Decode
import Vector exposing (Vector)
import Quaternion exposing (Quaternion)
import Frame
import Collision.Tree as Tree exposing (Tree(..))
import Collision.Face as Face
import Collision.OBBTree as OBBTree exposing (Body)


testSuite : Test
testSuite =
    suite "Collision detection"
        [ collisionRecursionSuite
        , centeredCollisionSuite
        , offCenterCollisionSuite
        , projectAndSplitSuite
        , jsonSuite
        ]


collisionRecursionSuite : Test
collisionRecursionSuite =
    let
        xf =
            { nodeNode = (==)
            , leafLeaf = (==)
            , nodeLeaf = flip List.member
            , leafNode = List.member
            }

        assertHit a b =
            assertEqual True (OBBTree.collideRecurse xf a b)

        assertMiss a b =
            assertEqual False (OBBTree.collideRecurse xf a b)
    in
        suite "recursive condition checking"
            [ test "non-colliding leafs do not collide" <|
                assertMiss (Leaf 1)
                    (Leaf 2)
            , test "colliding leafs collide" <|
                assertHit (Leaf 1)
                    (Leaf 1)
            , test "false if leaf collides with node but not children" <|
                assertMiss (Leaf 1)
                    (Node [ 1 ] (Leaf 2) (Leaf 3))
            , test "true if leaf collides with node and the first child" <|
                assertHit (Leaf 1)
                    (Node [ 1 ] (Leaf 1) (Leaf 3))
            , test "true if leaf collides with node and the second child" <|
                assertHit (Leaf 1)
                    (Node [ 1 ] (Leaf 3) (Leaf 1))
            , test "false if leaf collides with children but not node" <|
                assertMiss (Leaf 1)
                    (Node [ 2 ] (Leaf 1) (Leaf 2))
            , test "false if node but not children collide with leaf" <|
                assertMiss (Node [ 1 ] (Leaf 2) (Leaf 3))
                    (Leaf 1)
            , test "true if node and first child collide with leaf" <|
                assertHit (Node [ 1 ] (Leaf 1) (Leaf 3))
                    (Leaf 1)
            , test "true if node and second child collide with leaf" <|
                assertHit (Node [ 1 ] (Leaf 3) (Leaf 1))
                    (Leaf 1)
            , test "false if children but not node collide with leaf" <|
                assertMiss (Node [ 2 ] (Leaf 1) (Leaf 3))
                    (Leaf 1)
            , test "false if nodes but no children collide" <|
                assertMiss (Node [ 1 ] (Leaf 2) (Leaf 3))
                    (Node [ 1 ] (Leaf 4) (Leaf 5))
            , test "false if children but not nodes collide" <|
                assertMiss (Node [ 1 ] (Leaf 2) (Leaf 3))
                    (Node [ 4 ] (Leaf 2) (Leaf 3))
            , test "true if first children collide" <|
                assertHit (Node [ 1 ] (Leaf 2) (Leaf 3))
                    (Node [ 1 ] (Leaf 2) (Leaf 4))
            , test "true if first child collides with second child" <|
                assertHit (Node [ 1 ] (Leaf 2) (Leaf 3))
                    (Node [ 1 ] (Leaf 4) (Leaf 2))
            , test "true if second child collides with first child" <|
                assertHit (Node [ 1 ] (Leaf 2) (Leaf 3))
                    (Node [ 1 ] (Leaf 3) (Leaf 4))
            , test "true if second children collide" <|
                assertHit (Node [ 1 ] (Leaf 2) (Leaf 3))
                    (Node [ 1 ] (Leaf 4) (Leaf 3))
            ]


{-| collisions where bounding box is centered on the
origin of the body's reference frame
-}
centeredCollisionSuite : Test
centeredCollisionSuite =
    let
        box =
            Node
                { a = 3
                , b = 2
                , c = 1
                , frame = Frame.identity
                }
                (Leaf
                    { p = Vector.vector 3 2 1
                    , q = Vector.vector -3 2 1
                    , r = Vector.vector -3 -2 1
                    }
                )
                (Leaf
                    { p = Vector.vector 3 2 1
                    , q = Vector.vector 3 2 -1
                    , r = Vector.vector -3 2 1
                    }
                )

        assertHit a b =
            assertEqual True
                (OBBTree.collide { a | bounds = box } { b | bounds = box })

        assertMiss a b =
            assertEqual False
                (OBBTree.collide { a | bounds = box } { b | bounds = box })
    in
        suite "Body collisions"
            [ test "bodies that do not collide" <|
                assertMiss
                    defaultBody
                    (setPosition (Vector.vector 10 0 0) defaultBody)
            , test "aligned bodies that do collide" <|
                assertHit
                    defaultBody
                    (setPosition (Vector.vector 1 0 0) defaultBody)
            , test "unaligned bodies that do collide" <|
                assertHit
                    (setOrientation (Quaternion.rotateX (degrees -36.9)) defaultBody)
                    (setOrientation (Quaternion.rotateY (degrees 20.8)) defaultBody)
            , test "unaligned bodies that do not collide" <|
                assertMiss
                    (defaultBody
                        |> setPosition (Vector.vector 0 0 -2)
                        |> setOrientation (Quaternion.rotateX (degrees -36.8))
                    )
                    (defaultBody
                        |> setPosition (Vector.vector 0 0 2)
                        |> setOrientation (Quaternion.rotateY (degrees 20.7))
                    )
            ]


{-| Bounding box is offset from the body's origin
-}
offCenterCollisionSuite : Test
offCenterCollisionSuite =
    let
        triangle =
            { p = Vector.vector -1 -1 -10
            , q = Vector.vector 1 1 -10
            , r = Vector.vector 0 0 -12
            }

        box =
            { a = 3
            , b = 0.1
            , c = 0.1
            , frame =
                { position = Vector.vector 0 0 -10
                , orientation = Quaternion.rotateY (degrees 45)
                }
            }

        aFrame =
            { position = Vector.vector 0 10 0
            , orientation = Quaternion.rotateX (degrees -90)
            }

        bFrame =
            { position = Vector.vector 10 0 0
            , orientation = Quaternion.rotateY (degrees 90)
            }

        leafTree =
            Leaf triangle

        boxTree =
            Node box (Leaf triangle) (Leaf triangle)
    in
        suite "Off-center body collisions"
            [ test "two faces rotated to the same location" <|
                assertEqual True
                    (OBBTree.collide
                        { bounds = Leaf triangle, frame = aFrame }
                        { bounds = Leaf triangle, frame = bFrame }
                    )
            , test "two boxes rotated to the same location" <|
                assertEqual True
                    (OBBTree.collide
                        { bounds = boxTree, frame = aFrame }
                        { bounds = boxTree, frame = bFrame }
                    )
            ]


projectAndSplitSuite : Test
projectAndSplitSuite =
    let
        one =
            Face.face (Vector.vector 1 1 1)
                (Vector.vector 1 1 1)
                (Vector.vector 1 1 1)

        two =
            Face.face (Vector.vector 2 2 2)
                (Vector.vector 2 2 2)
                (Vector.vector 2 2 2)

        three =
            Face.face (Vector.vector 3 3 3)
                (Vector.vector 3 3 3)
                (Vector.vector 3 3 3)

        four =
            Face.face (Vector.vector 4 4 4)
                (Vector.vector 4 4 4)
                (Vector.vector 4 4 4)

        five =
            Face.face (Vector.vector 5 5 5)
                (Vector.vector 5 5 5)
                (Vector.vector 5 5 5)

        facts x face =
            { face = face
            , area = 0
            , center = Vector.vector x 0 0
            }

        projectAndSplit =
            OBBTree.projectAndSplit (Vector.vector 1 0 0)
    in
        suite "Box splitting"
            [ test "split fails if projections are identical" <|
                assertEqual Nothing
                    (projectAndSplit
                        [ facts 1 one
                        , facts 1 two
                        , facts 1 three
                        , facts 1 four
                        , facts 1 five
                        ]
                    )
            , test "split halfway point if projections are different and list size is even" <|
                assertEqual (Just ( [ one, two ], [ three, four ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 2 two
                        , facts 3 three
                        , facts 4 four
                        ]
                    )
            , test "split just after halfway point if projections are different and list size is odd" <|
                assertEqual (Just ( [ one, two, three ], [ four, five ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 2 two
                        , facts 3 three
                        , facts 4 four
                        , facts 5 five
                        ]
                    )
            , test "split by value if 4 items of lower and 1 of higher" <|
                assertEqual (Just ( [ one, two, three, four ], [ five ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 1 two
                        , facts 1 three
                        , facts 1 four
                        , facts 2 five
                        ]
                    )
            , test "split by value if 3 items of lower and 2 of higher" <|
                assertEqual (Just ( [ one, two, three ], [ four, five ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 1 two
                        , facts 1 three
                        , facts 2 four
                        , facts 2 five
                        ]
                    )
            , test "split by value if 2 items of lower and 3 of higher" <|
                assertEqual (Just ( [ one, two ], [ three, four, five ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 1 two
                        , facts 2 three
                        , facts 2 four
                        , facts 2 five
                        ]
                    )
            , test "split by value if 1 item of lower and 4 of higher" <|
                assertEqual (Just ( [ one ], [ two, three, four, five ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 2 two
                        , facts 2 three
                        , facts 2 four
                        , facts 2 five
                        ]
                    )
            , test "median group goes to first half even if split is very unbalanced" <|
                assertEqual (Just ( [ one, two, three, four ], [ five ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 1 two
                        , facts 2 three
                        , facts 2 four
                        , facts 3 five
                        ]
                    )
            , test "median group goes to first half even if split is unbalanced" <|
                assertEqual (Just ( [ one, two, three ], [ four, five ] ))
                    (projectAndSplit
                        [ facts 1 one
                        , facts 2 two
                        , facts 2 three
                        , facts 3 four
                        , facts 3 five
                        ]
                    )
            , test "tolerance in floating point comparisons" <|
                assertEqual Nothing
                    (projectAndSplit
                        [ facts 0 one
                        , facts 1.0e-10 two
                        , facts -1.0e-10 three
                        ]
                    )
            ]


jsonSuite : Test
jsonSuite =
    let
        assertLosslessJson tree =
            assertEqual
                (Ok tree)
                (Decode.decodeValue OBBTree.decode (OBBTree.encode tree))
    in
        suite "encoding and decoding json"
            [ test "leaf encodes and decodes again without losing data" <|
                assertLosslessJson
                    (Leaf
                        { p = Vector.vector 1 2 3
                        , q = Vector.vector 4 5 6
                        , r = Vector.vector 7 8 9
                        }
                    )
            , test "node encodes and decodes again without losing data" <|
                assertLosslessJson
                    (Node
                        { a = 1, b = 2, c = 3, frame = Frame.identity }
                        (Leaf
                            { p = Vector.vector 4 5 6
                            , q = Vector.vector 7 8 9
                            , r = Vector.vector 10 11 12
                            }
                        )
                        (Leaf
                            { p = Vector.vector 13 14 15
                            , q = Vector.vector 16 17 18
                            , r = Vector.vector 19 20 21
                            }
                        )
                    )
            ]


defaultBody : Body {}
defaultBody =
    { frame = Frame.identity
    , bounds = OBBTree.empty
    }


setPosition : Vector -> Body a -> Body a
setPosition p box =
    { box | frame = Frame.setPosition p box.frame }


setOrientation : Quaternion -> Body a -> Body a
setOrientation q box =
    { box | frame = Frame.setOrientation q box.frame }
