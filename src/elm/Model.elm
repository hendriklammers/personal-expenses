module Model exposing
    ( Error
    , ErrorType(..)
    , Flags
    , MenuState(..)
    , Modal
    , Model
    , Msg(..)
    , Sort(..)
    , TableSort
    , endSettings
    , init
    , startSettings
    , update
    )

import Browser
import Browser.Navigation as Nav
import Date exposing (Date)
import DatePicker exposing (DateEvent(..), defaultSettings)
import Dict exposing (Dict)
import Exchange
    exposing
        ( Exchange
        , exchangeDecoder
        , exchangeEncoder
        , ratesDecoder
        )
import Expense
    exposing
        ( Category
        , Currencies
        , Currency
        , Expense
        , currencyDecoder
        , currencyEncoder
        , currencyListDecoder
        , downloadExpenses
        , expenseListDecoder
        , expenseListEncoder
        )
import File exposing (File)
import File.Select as Select
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import List.Extra exposing (find)
import Ports
import Random exposing (Seed, initialSeed, step)
import Route exposing (Route(..), toRoute)
import Task
import Time
import Url
import Url.Builder as Builder
import Uuid


type alias Model =
    { amount : Maybe Float
    , category : Maybe Category
    , categories : List Category
    , currency : Maybe Currency
    , currencies : Currencies
    , seed : Seed
    , expenses : List Expense
    , error : Maybe Error
    , key : Nav.Key
    , route : Route
    , menu : MenuState
    , exchange : Maybe Exchange
    , startDate : Maybe Date
    , endDate : Maybe Date
    , startDatePicker : DatePicker.DatePicker
    , endDatePicker : DatePicker.DatePicker
    , timeZone : Time.Zone
    , fetchingExchange : Bool
    , overviewTableSort : TableSort
    , currencyTableSort : TableSort
    , modal : Maybe Modal

    -- Allows user to edit active currencies
    -- Probably better to make Modal more generic
    , showCurrencies : Bool
    }


type Msg
    = UpdateAmount String
    | SelectCategory Category
    | SelectCurrency String
    | Submit
    | AddExpense Time.Posix
    | CloseError
    | ToggleMenu
    | ReceiveExchangeRates (Result Http.Error (Dict String Float))
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ToStartDatePicker DatePicker.Msg
    | ToEndDatePicker DatePicker.Msg
    | LoadExchange
    | DeleteStartDate
    | DeleteEndDate
    | SetTimeZone Time.Zone
    | SetTimestamp (Dict String Float) Time.Posix
    | ReceiveCurrencies (Result Http.Error (List Currency))
    | RowClick String
    | SortOverviewTable String
    | SortCurrencyTable String
    | CloseCurrencyOverview
    | ExportData
    | ImportData
    | FileSelected File
    | FileLoaded String
    | DeleteData
    | ShowModal Modal
    | CloseModal
    | OverwriteExpenses (List Expense)
    | OpenCurrencies
    | CloseCurrencies
    | CurrencyToggleSelected Currency
    | SaveSelectedCurrencies


type MenuState
    = MenuOpen
    | MenuClosed


type ErrorType
    = InputError
    | FetchError


type Sort
    = ASC
    | DESC


type alias TableSort =
    Maybe ( String, Sort )


type alias Modal =
    { action : Msg
    , color : String
    , label : String
    , message : String
    }


type alias Error =
    ( ErrorType, String )


type alias Flags =
    { seed : Int
    , currency : Maybe String
    , exchange : Maybe String
    , expenses : Maybe String
    }


categories : List Category
categories =
    [ { id = "5772822A-42B4-4605-A5C3-0504498C3432"
      , name = "Food & Drink"
      }
    , { id = "E7C07380-2899-4979-84B2-087E68BAC60C"
      , name = "Accomodation"
      }
    , { id = "92149113-B678-4EEE-ACB6-E346990A35B8"
      , name = "Transportation"
      }
    , { id = "6E632105-8A84-490F-AD33-A543E51669AE"
      , name = "Shopping"
      }
    , { id = "43641EFB-97D3-482D-9A6D-E2193979E383"
      , name = "Trips & Attractions"
      }
    , { id = "6063E8E0-0190-4DF6-8B35-D5F332F799FA"
      , name = "Other"
      }
    ]


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( startDatePicker, startDatePickerFx ) =
            DatePicker.init

        ( endDatePicker, endDatePickerFx ) =
            DatePicker.init
    in
    ( { amount = Nothing
      , category = List.head categories
      , categories = categories
      , currency = jsonFlag currencyDecoder flags.currency
      , currencies = Dict.empty
      , seed = initialSeed flags.seed
      , expenses =
            Maybe.withDefault []
                (jsonFlag expenseListDecoder flags.expenses)
      , error = Nothing
      , key = key
      , route = toRoute url
      , menu = MenuClosed
      , exchange = jsonFlag exchangeDecoder flags.exchange
      , startDate = Nothing
      , startDatePicker = startDatePicker
      , endDate = Nothing
      , endDatePicker = endDatePicker
      , timeZone = Time.utc
      , fetchingExchange = False
      , overviewTableSort = Nothing
      , currencyTableSort = Nothing
      , modal = Nothing
      , showCurrencies = False
      }
    , Cmd.batch
        [ Cmd.map ToStartDatePicker startDatePickerFx
        , Cmd.map ToEndDatePicker endDatePickerFx
        , Task.perform SetTimeZone Time.here
        , fetchCurrencies
        ]
    )


jsonFlag : Decode.Decoder a -> Maybe String -> Maybe a
jsonFlag decoder flag =
    Maybe.andThen
        (Decode.decodeString decoder >> Result.toMaybe)
        flag


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateAmount value ->
            ( { model | amount = String.toFloat value }
            , Cmd.none
            )

        Submit ->
            ( model, Task.perform AddExpense Time.now )

        AddExpense date ->
            addExpense model date

        SelectCategory category ->
            ( { model | category = Just category }
            , Cmd.none
            )

        SelectCurrency selected ->
            case Dict.get selected model.currencies of
                Just currency ->
                    let
                        cmd =
                            currency
                                |> currencyEncoder
                                |> Encode.encode 0
                                |> Ports.storeCurrency
                    in
                    ( { model | currency = Just currency }, cmd )

                Nothing ->
                    ( { model
                        | error =
                            Just
                                ( InputError
                                , "Invalid currency selected"
                                )
                      }
                    , Cmd.none
                    )

        CloseError ->
            ( { model | error = Nothing }
            , Cmd.none
            )

        ToggleMenu ->
            let
                state =
                    case model.menu of
                        MenuOpen ->
                            MenuClosed

                        MenuClosed ->
                            MenuOpen
            in
            ( { model | menu = state }
            , Cmd.none
            )

        ReceiveCurrencies result ->
            case result of
                Ok currencies ->
                    ( { model
                        | currencies =
                            currencies
                                |> List.map (\cur -> ( cur.code, cur ))
                                |> Dict.fromList
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( { model
                        | error =
                            Just
                                ( FetchError
                                , "Unable to fetch the currency list from the server"
                                )
                      }
                    , Cmd.none
                    )

        ReceiveExchangeRates result ->
            case result of
                Ok rates ->
                    ( { model | fetchingExchange = False }
                    , Task.perform (SetTimestamp rates) Time.now
                    )

                Err _ ->
                    ( { model
                        | fetchingExchange = False
                        , error =
                            Just
                                ( FetchError
                                , "Unable to fetch the exchange rates from the API"
                                )
                      }
                    , Cmd.none
                    )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model
                | route = toRoute url
                , menu = MenuClosed
              }
            , Cmd.none
            )

        ToStartDatePicker subMsg ->
            let
                ( newDatePicker, dateEvent ) =
                    DatePicker.update
                        (startSettings model.endDate)
                        subMsg
                        model.startDatePicker

                newDate =
                    case dateEvent of
                        Picked changedDate ->
                            Just changedDate

                        _ ->
                            model.startDate
            in
            ( { model
                | startDate = newDate
                , startDatePicker = newDatePicker
              }
            , Cmd.none
            )

        ToEndDatePicker subMsg ->
            let
                ( newDatePicker, dateEvent ) =
                    DatePicker.update
                        (endSettings model.startDate)
                        subMsg
                        model.endDatePicker

                newDate =
                    case dateEvent of
                        Picked changedDate ->
                            Just changedDate

                        _ ->
                            model.endDate
            in
            ( { model
                | endDate = newDate
                , endDatePicker = newDatePicker
              }
            , Cmd.none
            )

        DeleteStartDate ->
            ( { model | startDate = Nothing }, Cmd.none )

        DeleteEndDate ->
            ( { model | endDate = Nothing }, Cmd.none )

        LoadExchange ->
            ( { model | fetchingExchange = True }, fetchRates )

        SetTimeZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        SetTimestamp rates time ->
            let
                exchange =
                    Exchange time rates
            in
            ( { model | exchange = Just exchange }
            , Ports.storeExchange (exchangeEncoder exchange)
            )

        RowClick currency ->
            ( model
            , Nav.pushUrl
                model.key
                (Builder.absolute [ "overview", currency ] [])
            )

        SortOverviewTable column ->
            ( { model
                | overviewTableSort =
                    updateTableSort column model.overviewTableSort
              }
            , Cmd.none
            )

        SortCurrencyTable column ->
            ( { model
                | currencyTableSort =
                    updateTableSort column model.currencyTableSort
              }
            , Cmd.none
            )

        CloseCurrencyOverview ->
            ( model, Nav.pushUrl model.key "/overview" )

        ExportData ->
            ( model, downloadExpenses model.expenses )

        ImportData ->
            -- TODO: Add option to append to current data
            ( model, Select.file [ "application/json" ] FileSelected )

        FileSelected file ->
            ( model, Task.perform FileLoaded (File.toString file) )

        FileLoaded string ->
            let
                expenses =
                    Result.withDefault
                        []
                        (Decode.decodeString expenseListDecoder string)

                modal =
                    { action = OverwriteExpenses expenses
                    , color = "is-warning"
                    , label = "Import"
                    , message = "This will overwrite all existing data. Are you sure?"
                    }
            in
            ( { model | modal = Just modal }, Cmd.none )

        OverwriteExpenses expenses ->
            ( { model | expenses = expenses, modal = Nothing }
            , Ports.storeExpenses (expenseListEncoder 0 expenses)
            )

        DeleteData ->
            ( { model | expenses = [], modal = Nothing }
            , Ports.storeExpenses ""
            )

        ShowModal modal ->
            ( { model | modal = Just modal }, Cmd.none )

        CloseModal ->
            ( { model | modal = Nothing }, Cmd.none )

        OpenCurrencies ->
            ( { model
                | showCurrencies = True
                , currencies =
                    Dict.map
                        (\_ currency ->
                            { currency
                                | selected = currency.active
                            }
                        )
                        model.currencies
              }
            , Cmd.none
            )

        CloseCurrencies ->
            ( { model
                | showCurrencies = False
                , currencies =
                    Dict.map
                        (\_ currency ->
                            { currency
                                | selected = False
                            }
                        )
                        model.currencies
              }
            , Cmd.none
            )

        CurrencyToggleSelected { code } ->
            ( { model
                | currencies = toggleCurrencySelect code model.currencies
              }
            , Cmd.none
            )

        SaveSelectedCurrencies ->
            ( { model
                | currencies =
                    Dict.map
                        (\_ currency ->
                            { currency
                                | active = currency.selected
                                , selected = False
                            }
                        )
                        model.currencies
                , showCurrencies = False
              }
            , Cmd.none
            )


toggleCurrencySelect : String -> Currencies -> Currencies
toggleCurrencySelect code currencies =
    Dict.update
        code
        (Maybe.map (\currency -> { currency | selected = not currency.selected }))
        currencies


updateTableSort : String -> TableSort -> TableSort
updateTableSort name current =
    case current of
        Nothing ->
            Just ( name, DESC )

        Just ( currentName, sort ) ->
            if name == currentName then
                case sort of
                    DESC ->
                        Just ( name, ASC )

                    ASC ->
                        Nothing

            else
                Just ( name, DESC )


startSettings : Maybe Date -> DatePicker.Settings
startSettings endDate =
    let
        isDisabled =
            case endDate of
                Nothing ->
                    defaultSettings.isDisabled

                Just date ->
                    \d ->
                        Date.toRataDie d
                            > Date.toRataDie date
                            || defaultSettings.isDisabled d
    in
    { defaultSettings
        | placeholder = "Start date"
        , isDisabled = isDisabled
    }


endSettings : Maybe Date -> DatePicker.Settings
endSettings startDate =
    let
        isDisabled =
            case startDate of
                Nothing ->
                    defaultSettings.isDisabled

                Just date ->
                    \d ->
                        Date.toRataDie d
                            < Date.toRataDie date
                            || defaultSettings.isDisabled d
    in
    { defaultSettings
        | placeholder = "End date"
        , isDisabled = isDisabled
    }


fetchCurrencies : Cmd Msg
fetchCurrencies =
    Http.get
        { url = "/currencies.json"
        , expect = Http.expectJson ReceiveCurrencies currencyListDecoder
        }


fetchRates : Cmd Msg
fetchRates =
    Http.get
        { url = "https://api.exchangeratesapi.io/latest?base=EUR"
        , expect = Http.expectJson ReceiveExchangeRates ratesDecoder
        }


addExpense : Model -> Time.Posix -> ( Model, Cmd Msg )
addExpense model date =
    let
        ( id, seed ) =
            step Uuid.uuidGenerator model.seed
    in
    case
        Maybe.map3
            (Expense id date)
            model.amount
            model.category
            model.currency
    of
        Just e ->
            ( { model
                | seed = seed
                , amount = Nothing
                , error = Nothing
                , expenses = e :: model.expenses
              }
            , Ports.storeExpenses (expenseListEncoder 0 (e :: model.expenses))
            )

        Nothing ->
            ( { model | error = Just ( InputError, "Invalid input" ) }
            , Cmd.none
            )
