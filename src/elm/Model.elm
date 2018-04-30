module Model exposing (Model, initial, update)

import Task
import Date
import Dict exposing (Dict)
import Messages exposing (Msg(..))
import Types
    exposing
        ( Category
        , Expense
        , Currency
        , MenuState(..)
        , Page(..)
        )
import Routing exposing (parseLocation)
import Random.Pcg exposing (Seed, initialSeed, step)
import Uuid


type alias Model =
    { amount : Float
    , category : Category
    , categories : List Category
    , currency : Currency
    , currencies : Dict String Currency
    , currentSeed : Seed
    , expenses : List Expense
    , error : Maybe String
    , page : Page
    , menu : MenuState
    }


categories : List Category
categories =
    [ { id = 0
      , name = "Food & Drink"
      }
    , { id = 1
      , name = "Accomodation"
      }
    , { id = 2
      , name = "Transportation"
      }
    , { id = 3
      , name = "Shopping"
      }
    , { id = 4
      , name = "Trips & Attractions"
      }
    , { id = 5
      , name = "Other"
      }
    ]


currencies : List Currency
currencies =
    [ { code = "USD"
      , name = "United States Dollar"
      }
    , { code = "EUR"
      , name = "Euro"
      }
    , { code = "THB"
      , name = "Thai Baht"
      }
    , { code = "VND"
      , name = "Vietnamese Dong"
      }
    , { code = "KHR"
      , name = "Cambodian Riel"
      }
    , { code = "LAK"
      , name = "Laotian Kip"
      }
    , { code = "MYR"
      , name = "Malaysian Ringgit"
      }
    , { code = "SGD"
      , name = "Singapore Dollar"
      }
    , { code = "IDR"
      , name = "Indonesian Rupiah"
      }
    ]


currenciesDict : List Currency -> Dict String Currency
currenciesDict currencies =
    currencies
        |> List.sortBy .code
        |> List.map (\c -> ( c.code, c ))
        |> Dict.fromList


initial : Int -> Page -> Model
initial seed page =
    { amount = 0
    , category =
        { id = 0
        , name = "Food & Drink"
        }
    , categories = categories
    , currency =
        { code = "USD"
        , name = "United States Dollar"
        }
    , currencies = currenciesDict currencies
    , currentSeed = initialSeed seed
    , expenses = []
    , error = Nothing
    , page = page
    , menu = MenuClosed
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateAmount value ->
            let
                amount =
                    case String.toFloat value of
                        Ok result ->
                            result

                        Err _ ->
                            0
            in
                { model | amount = amount } ! []

        Submit ->
            if model.amount <= 0 then
                handleError model "Please enter the amount of money spent"
            else
                ( model, Task.perform ReceiveDate Date.now )

        ReceiveDate date ->
            let
                ( id, newSeed ) =
                    step Uuid.uuidGenerator model.currentSeed

                expense =
                    { category = model.category
                    , amount = model.amount
                    , currency = model.currency
                    , date = date
                    , id = id
                    }
            in
                { model
                    | currentSeed = newSeed
                    , expenses = expense :: model.expenses
                }
                    ! []

        SelectCategory category ->
            { model | category = category } ! []

        SelectCurrency selected ->
            case Dict.get selected model.currencies of
                Just currency ->
                    { model | currency = currency } ! []

                Nothing ->
                    handleError model "Invalid currency selected"

        CloseError ->
            { model | error = Nothing } ! []

        ToggleMenu ->
            let
                state =
                    case model.menu of
                        MenuOpen ->
                            MenuClosed

                        MenuClosed ->
                            MenuOpen
            in
                { model | menu = state } ! []

        LocationChange location ->
            { model | page = parseLocation location, menu = MenuClosed } ! []


handleError : Model -> String -> ( Model, Cmd Msg )
handleError model message =
    { model | error = Just message } ! []
