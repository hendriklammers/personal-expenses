module View.View exposing (view)

import Browser
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , h1
        , nav
        , span
        , text
        )
import Html.Attributes as H
import Html.Attributes.Aria as Aria
import Html.Events exposing (onClick)
import Messages exposing (Msg(..))
import Model exposing (Error, MenuState(..), Model)
import View.InputPage as InputPageView
import View.OverviewPage as OverviewPageView


type Page
    = InputPage
    | OverviewPage


type alias MenuItem =
    ( String, Page )


viewNavbar : Model -> Html Msg
viewNavbar model =
    nav
        [ H.class "navbar is-dark"
        , Aria.role "navigation"
        , Aria.ariaLabel "main navigation"
        ]
        [ div
            [ H.class "navbar-brand" ]
            [ h1
                [ H.class "navbar-item is-capitalized" ]
                [ text "Travel expenses" ]
            , viewBurger model
            ]
        , viewMenu model
        ]


viewBurger : Model -> Html Msg
viewBurger { menu } =
    div
        [ H.class ("navbar-burger" ++ menuClass menu)
        , onClick ToggleMenu
        ]
        (List.map (\_ -> span [] []) (List.range 0 2))


menuClass : MenuState -> String
menuClass state =
    case state of
        MenuOpen ->
            " is-active"

        MenuClosed ->
            ""


menuItems : List MenuItem
menuItems =
    [ ( "Input", InputPage )
    , ( "Overview", OverviewPage )
    ]


viewMenuItem : Page -> MenuItem -> Html Msg
viewMenuItem active ( label, page ) =
    let
        activeClass =
            if active == page then
                " is-active"

            else
                ""

        href =
            "/#" ++ String.toLower label
    in
    a
        [ H.href href
        , H.class ("navbar-item is-capitalized" ++ activeClass)
        ]
        [ text label ]


viewMenu : Model -> Html Msg
viewMenu { menu } =
    let
        active =
            InputPage
    in
    div
        [ H.class ("navbar-menu" ++ menuClass menu) ]
        [ div
            [ H.class "navbar-end" ]
            (List.map (viewMenuItem active) menuItems)
        ]



-- viewPage : Model -> Html Msg
-- viewPage model =
--     case model.page of
--         InputPage ->
--             InputPageView.view model
--
--         OverviewPage ->
--             OverviewPageView.view model


viewError : Maybe Error -> Html Msg
viewError error =
    case error of
        Just ( _, message ) ->
            div
                [ H.class "notification is-danger is-marginless is-radiusless" ]
                [ button
                    [ H.class "delete"
                    , onClick CloseError
                    ]
                    []
                , text message
                ]

        Nothing ->
            text ""


view : Model -> Browser.Document Msg
view model =
    { title = "Travel Expenses"
    , body =
        [ div
            [ H.class "container-fluid" ]
            [ viewError model.error
            , viewNavbar model
            , InputPageView.view model

            -- , viewPage model
            ]
        ]
    }
