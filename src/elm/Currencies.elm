module Currencies exposing (view)

import Dict
import Expense exposing (Currency)
import Html
    exposing
        ( Html
        , article
        , button
        , div
        , input
        , span
        , table
        , tbody
        , td
        , text
        , th
        , thead
        , tr
        )
import Html.Attributes as H
import Html.Events exposing (onClick)
import Model exposing (Model, Msg(..))


viewRow : Currency -> Html Msg
viewRow ({ code, name, active, selected } as currency) =
    tr [ H.class "row" ]
        [ td [] [ text code ]
        , td [] [ text name ]
        , td []
            [ input
                [ H.type_ "checkbox"
                , H.checked selected
                , onClick (CurrencyToggleSelected currency)
                ]
                []
            ]
        ]


viewTable : Model -> Html Msg
viewTable model =
    table
        [ H.class "table is-fullwidth is-marginless" ]
        [ thead []
            [ tr []
                [ th
                    []
                    [ span []
                        [ text "Code" ]
                    ]
                , th
                    []
                    [ span []
                        [ text "Name" ]
                    ]
                , th
                    []
                    [ span []
                        [ text "Active" ]
                    ]
                ]
            ]
        , tbody []
            (model.currencies
                |> Dict.toList
                |> List.map (Tuple.second >> viewRow)
            )
        ]


view : Model -> Html Msg
view model =
    let
        color =
            "is-info"

        title =
            "Active currencies"
    in
    div
        [ H.class "modal active-currencies" ]
        [ div
            [ H.class "modal-background"
            , onClick (ShowCurrencies False)
            ]
            []
        , div [ H.class "modal-content" ]
            [ article [ H.class ("message " ++ color) ]
                [ div [ H.class "message-header" ]
                    [ span []
                        [ text title ]
                    , button
                        [ H.class "delete"
                        , onClick (ShowCurrencies False)
                        ]
                        [ text "Close" ]
                    ]
                , div [ H.class "message-body has-text-grey-dark has-background-white is-paddingless" ]
                    [ viewTable model
                    ]
                , div [ H.class "message-footer" ]
                    [ div [ H.class "buttons" ]
                        [ button
                            [ H.class "button"
                            , onClick (ShowCurrencies False)
                            ]
                            [ text "Cancel" ]
                        , button
                            [ H.class "button is-primary"
                            , onClick SaveSelectedCurrencies
                            ]
                            [ text "Save" ]
                        ]
                    ]
                ]
            ]
        ]
