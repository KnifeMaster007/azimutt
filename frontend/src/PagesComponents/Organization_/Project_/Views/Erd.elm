module PagesComponents.Organization_.Project_.Views.Erd exposing (ErdArgs, argsToString, stringToArgs, viewErd)

import Components.Atoms.Badge as Badge
import Components.Atoms.Icon as Icon exposing (Icon(..))
import Components.Molecules.Tooltip as Tooltip
import Conf
import Dict exposing (Dict)
import Html exposing (Html, button, div, h2, p, text)
import Html.Attributes exposing (class, classList, id)
import Html.Events exposing (onClick)
import Html.Events.Extra.Mouse exposing (Button(..))
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Libs.Bool as B
import Libs.Dict as Dict
import Libs.Html exposing (bText, extLink, sendTweet)
import Libs.Html.Attributes exposing (css)
import Libs.Html.Events exposing (PointerEvent, onContextMenu, onDblClick, onWheel, stopPointerDown)
import Libs.List as List
import Libs.Maybe as Maybe
import Libs.Models.HtmlId exposing (HtmlId)
import Libs.Models.Platform as Platform exposing (Platform)
import Libs.Models.ZoomLevel exposing (ZoomLevel)
import Libs.String as String
import Libs.Tailwind as Tw exposing (focus)
import Libs.Tuple as Tuple
import Models.Area as Area
import Models.ErdProps exposing (ErdProps)
import Models.Position as Position
import Models.Project.CanvasProps as CanvasProps exposing (CanvasProps)
import Models.Project.Metadata exposing (Metadata)
import Models.Project.SchemaName exposing (SchemaName)
import Models.Project.TableId as TableId exposing (TableId)
import Models.Project.TableMeta as TableMeta exposing (TableMeta)
import Models.RelationStyle exposing (RelationStyle)
import Models.Size as Size
import PagesComponents.Organization_.Project_.Components.DetailsSidebar as DetailsSidebar
import PagesComponents.Organization_.Project_.Models exposing (MemoEdit, MemoMsg(..), Msg(..), VirtualRelation)
import PagesComponents.Organization_.Project_.Models.CursorMode as CursorMode exposing (CursorMode)
import PagesComponents.Organization_.Project_.Models.DragState exposing (DragState)
import PagesComponents.Organization_.Project_.Models.Erd as Erd exposing (Erd)
import PagesComponents.Organization_.Project_.Models.ErdColumn exposing (ErdColumn)
import PagesComponents.Organization_.Project_.Models.ErdConf exposing (ErdConf)
import PagesComponents.Organization_.Project_.Models.ErdLayout exposing (ErdLayout)
import PagesComponents.Organization_.Project_.Models.ErdRelation exposing (ErdRelation)
import PagesComponents.Organization_.Project_.Models.ErdTable exposing (ErdTable)
import PagesComponents.Organization_.Project_.Models.ErdTableLayout exposing (ErdTableLayout)
import PagesComponents.Organization_.Project_.Models.ErdTableProps exposing (ErdTableProps)
import PagesComponents.Organization_.Project_.Models.Memo exposing (Memo)
import PagesComponents.Organization_.Project_.Models.MemoId as MemoId
import PagesComponents.Organization_.Project_.Updates.Drag as Drag
import PagesComponents.Organization_.Project_.Views.Erd.Memo as Memo
import PagesComponents.Organization_.Project_.Views.Erd.Relation as Relation exposing (viewEmptyRelation, viewRelation, viewVirtualRelation)
import PagesComponents.Organization_.Project_.Views.Erd.Table as Table exposing (viewTable)
import PagesComponents.Organization_.Project_.Views.Modals.ErdContextMenu as ErdContextMenu
import Set exposing (Set)


type alias ErdArgs =
    String


argsToString : Platform -> CursorMode -> Maybe TableId -> String -> String -> DetailsSidebar.Selected -> ErdArgs
argsToString platform cursorMode hoverTable openedDropdown openedPopover selected =
    [ Platform.toString platform, CursorMode.toString cursorMode, hoverTable |> Maybe.mapOrElse TableId.toString "", openedDropdown, openedPopover, selected ] |> String.join "~"


stringToArgs : ErdArgs -> ( ( Platform, CursorMode, Maybe TableId ), ( String, String, DetailsSidebar.Selected ) )
stringToArgs args =
    case args |> String.split "~" of
        [ platform, cursorMode, hoverTable, openedDropdown, openedPopover, selected ] ->
            ( ( Platform.fromString platform, CursorMode.fromString cursorMode, hoverTable |> TableId.fromString ), ( openedDropdown, openedPopover, selected ) )

        _ ->
            ( ( Platform.PC, CursorMode.Select, Nothing ), ( "", "", "" ) )


viewErd : ErdConf -> ErdProps -> Erd -> Maybe Area.Canvas -> Maybe VirtualRelation -> Maybe MemoEdit -> ErdArgs -> Maybe DragState -> Html Msg
viewErd conf erdElem erd selectionBox virtualRelation editMemo args dragging =
    let
        ( ( platform, cursorMode, hoverTable ), ( openedDropdown, openedPopover, selected ) ) =
            stringToArgs args

        layout : ErdLayout
        layout =
            erd |> Erd.currentLayout

        canvas : CanvasProps
        canvas =
            dragging |> Maybe.filter (\d -> d.id == Conf.ids.erd) |> Maybe.mapOrElse (\d -> layout.canvas |> Drag.moveCanvas d) layout.canvas

        -- TODO: use to render only visible tables => needs to handle size change to 0...
        --canvasViewport : Area.Canvas
        --canvasViewport =
        --    canvas |> CanvasProps.viewport erdElem
        tableProps : List ErdTableLayout
        tableProps =
            dragging |> Maybe.filter (\d -> d.id /= Conf.ids.erd) |> Maybe.mapOrElse (\d -> layout.tables |> Drag.moveTables d canvas.zoom) layout.tables

        memos : List Memo
        memos =
            dragging |> Maybe.filter (.id >> MemoId.isHtmlId) |> Maybe.mapOrElse (\d -> layout.memos |> Drag.moveMemos d canvas.zoom) layout.memos

        displayedTables : List ErdTableLayout
        displayedTables =
            tableProps |> List.filter (\t -> t.props.size /= Size.zeroCanvas)

        displayedIds : Set TableId
        displayedIds =
            displayedTables |> List.map .id |> Set.fromList

        displayedRelations : List ErdRelation
        displayedRelations =
            erd.relations |> List.filter (\r -> [ r.src, r.ref ] |> List.any (\c -> displayedIds |> Set.member c.table))

        virtualRelationInfo : Maybe ( ( Maybe { table : ErdTableProps, index : Int, highlighted : Bool }, ErdColumn ), Position.Canvas )
        virtualRelationInfo =
            virtualRelation
                |> Maybe.andThen
                    (\vr ->
                        vr.src
                            |> Maybe.andThen
                                (\src ->
                                    (erd |> Erd.getColumn src)
                                        |> Maybe.map
                                            (\ref ->
                                                ( ( Relation.buildColumnInfo src.column (tableProps |> List.findBy .id src.table), ref )
                                                , vr.mouse |> Erd.viewportToCanvas erdElem canvas
                                                )
                                            )
                                )
                    )
    in
    div
        ([ id Conf.ids.erd
         , class "az-erd h-full bg-gray-100 overflow-hidden"
         , classList
            [ ( "invisible", erdElem.size == Size.zeroViewport )
            , ( "cursor-grab-all", cursorMode == CursorMode.Drag && dragging == Nothing && virtualRelation == Nothing )
            , ( "cursor-grabbing-all", cursorMode == CursorMode.Drag && dragging /= Nothing && virtualRelation == Nothing )
            , ( "cursor-crosshair-all", virtualRelation /= Nothing )
            ]
         ]
            ++ B.cond (conf.move && not (List.isEmpty tableProps)) [ onWheel platform OnWheel ] []
            ++ B.cond ((conf.move || conf.select) && virtualRelation == Nothing && editMemo == Nothing) [ stopPointerDown platform (handleErdPointerDown conf cursorMode) ] []
            ++ B.cond (conf.layout && virtualRelation == Nothing && editMemo == Nothing) [ onDblClick platform (CanvasProps.eventCanvas erdElem canvas >> MCreate >> MemoMsg), onContextMenu platform (\e -> ContextMenuCreate (ErdContextMenu.view platform erdElem canvas e) e) ] []
        )
        [ div [ class "az-canvas origin-top-left", Position.styleTransformDiagram canvas.position canvas.zoom ]
            -- use HTML order instead of z-index, must be careful with it, this allows to have tooltips & popovers always on top
            [ -- canvas.position |> Position.debugDiagram "canvas" "bg-black"
              -- , layout.tables |> List.map (.props >> Area.offGrid) |> Area.mergeCanvas |> Maybe.mapOrElse (Area.debugCanvas "tablesArea" "border-blue-500") (div [] []),
              displayedRelations |> Lazy.lazy5 viewRelations conf erd.settings.defaultSchema erd.settings.relationStyle displayedTables
            , tableProps |> viewTables platform conf cursorMode virtualRelation openedDropdown openedPopover hoverTable dragging canvas.zoom erd.settings.defaultSchema selected erd.settings.columnBasicTypes erd.tables erd.metadata
            , memos |> viewMemos platform conf cursorMode editMemo
            , div [ class "az-selection-box pointer-events-none" ] (selectionBox |> Maybe.filterNot (\_ -> tableProps |> List.isEmpty) |> Maybe.mapOrElse viewSelectionBox [])
            , div [ class "az-virtual-relation pointer-events-none" ] [ virtualRelationInfo |> Maybe.mapOrElse (\i -> viewVirtualRelation erd.settings.relationStyle i) viewEmptyRelation ]
            ]
        , if tableProps |> List.isEmpty then
            viewEmptyState erd.settings.defaultSchema erd.tables

          else
            div [] []
        ]


viewMemos : Platform -> ErdConf -> CursorMode -> Maybe MemoEdit -> List Memo -> Html Msg
viewMemos platform conf cursorMode editMemo memos =
    Keyed.node "div"
        [ class "az-memos" ]
        (memos
            |> List.map
                (\memo ->
                    ( MemoId.toHtmlId memo.id
                    , Lazy.lazy5 Memo.viewMemo platform conf cursorMode (editMemo |> Maybe.filterBy .id memo.id |> Maybe.map .content) memo
                    )
                )
        )


handleErdPointerDown : ErdConf -> CursorMode -> PointerEvent -> Msg
handleErdPointerDown conf cursorMode e =
    if e.button == MainButton then
        case cursorMode of
            CursorMode.Drag ->
                if conf.move then
                    e |> .clientPos |> DragStart Conf.ids.erd

                else
                    Noop "No erd drag"

            CursorMode.Select ->
                if conf.select then
                    e |> .clientPos |> DragStart Conf.ids.selectionBox

                else
                    Noop "No selection box"

    else if e.button == MiddleButton then
        if conf.move then
            e |> .clientPos |> DragStart Conf.ids.erd

        else
            Noop "No middle button erd drag"

    else
        Noop "No match on erd pointer down"


viewTables : Platform -> ErdConf -> CursorMode -> Maybe VirtualRelation -> HtmlId -> HtmlId -> Maybe TableId -> Maybe DragState -> ZoomLevel -> SchemaName -> DetailsSidebar.Selected -> Bool -> Dict TableId ErdTable -> Metadata -> List ErdTableLayout -> Html Msg
viewTables platform conf cursorMode virtualRelation openedDropdown openedPopover hoverTable dragging zoom defaultSchema selected useBasicTypes tables metadata tableLayouts =
    Keyed.node "div"
        [ class "az-tables" ]
        (tableLayouts
            |> List.reverse
            |> List.indexedMap Tuple.new
            |> List.filterMap (\( index, tableLayout ) -> tables |> Dict.get tableLayout.id |> Maybe.map (\table -> ( index, table, tableLayout )))
            |> List.map
                (\( index, table, tableLayout ) ->
                    ( TableId.toString table.id
                    , Lazy.lazy6 viewTable
                        conf
                        zoom
                        (Table.argsToString
                            platform
                            cursorMode
                            defaultSchema
                            (B.cond (openedDropdown |> String.startsWith table.htmlId) openedDropdown "")
                            (B.cond (openedPopover |> String.startsWith table.htmlId) openedPopover "")
                            index
                            selected
                            (hoverTable == Just table.id)
                            (dragging |> Maybe.any (\d -> d.id == table.htmlId && d.init /= d.last))
                            (virtualRelation /= Nothing)
                            useBasicTypes
                        )
                        (metadata |> Dict.getOrElse table.id TableMeta.empty)
                        tableLayout
                        table
                    )
                )
        )


viewRelations : ErdConf -> SchemaName -> RelationStyle -> List ErdTableLayout -> List ErdRelation -> Html Msg
viewRelations conf defaultSchema style tableLayouts relations =
    Keyed.node "div"
        [ class "az-relations" ]
        (relations
            |> List.map
                (\r ->
                    ( r.name
                    , Lazy.lazy6 viewRelation
                        defaultSchema
                        style
                        conf
                        (tableLayouts |> List.findBy .id r.src.table)
                        (tableLayouts |> List.findBy .id r.ref.table)
                        r
                    )
                )
        )


viewSelectionBox : Area.Canvas -> List (Html Msg)
viewSelectionBox area =
    [ div ([ css [ "absolute border-2 bg-opacity-25 z-max border-teal-400 bg-teal-400" ] ] ++ Area.styleTransformCanvas area) [] ]


viewEmptyState : SchemaName -> Dict TableId ErdTable -> Html Msg
viewEmptyState defaultSchema tables =
    let
        bestOneWordTables : List ErdTable
        bestOneWordTables =
            tables
                |> Dict.values
                |> List.filterNot (\t -> (t.schema |> String.contains "_") || (t.name |> String.contains "_") || (t.schema |> String.contains "-") || (t.name |> String.contains "-"))
                |> List.sortBy (\t -> (t.name |> String.length) - (t.columns |> Dict.size))
                |> List.take 10

        bestTables : List ErdTable
        bestTables =
            if bestOneWordTables |> List.isEmpty then
                tables
                    |> Dict.values
                    |> List.sortBy (\t -> (t.name |> String.length) - (t.columns |> Dict.size))
                    |> List.take 10

            else
                bestOneWordTables
    in
    div [ class "flex h-full justify-center items-center" ]
        [ div [ class "max-w-prose p-6 bg-white border border-gray-200 rounded-lg" ]
            [ div [ class "text-center" ]
                [ Icon.outline2x Template "mx-auto text-primary-500"
                , h2 [ class "mt-2 text-lg font-medium text-gray-900" ]
                    [ text "Hello from Azimutt 👋" ]
                , if tables |> Dict.isEmpty then
                    p [ class "mt-3 text-sm text-gray-500" ]
                        [ text "Azimutt allows you to create and explore your database schema. Start writing your schema using "
                        , extLink "https://github.com/azimuttapp/azimutt/blob/main/docs/aml/README.md" [ class "link" ] [ text "AML syntax" ]
                        , text " or import and explore your schema. Add any source (database url, SQL or JSON) in project settings (top right "
                        , Icon.outline Icon.Cog "h-5 w-5 inline"
                        , text ")."
                        ]

                  else
                    div []
                        [ p [ class "mt-3 text-sm text-gray-500" ]
                            [ text "Azimutt allows you to explore your database schema. Start by typing what you are looking for in the "
                            , button [ onClick (Focus Conf.ids.searchInput), css [ "link", focus [ "outline-none" ] ] ] [ text "search bar" ]
                            , text ", and then look at columns, follow relations and more... Create new layouts to save them for later."
                            ]
                        , p [ class "mt-3 text-sm text-gray-500" ]
                            [ text "Your project has "
                            , bText (tables |> String.pluralizeD "table")
                            , text ". Here are some that could be interesting:"
                            , div [] (bestTables |> List.map (\t -> Badge.roundedFlex Tw.primary [ onClick (ShowTable t.id Nothing), class "m-1 cursor-pointer" ] [ text (TableId.show defaultSchema t.id) ] |> Tooltip.t (t.columns |> String.pluralizeD "column")))
                            ]
                        ]
                , p [ class "mt-3 text-sm text-gray-500" ]
                    [ text "If you ❤️ Azimutt, "
                    , sendTweet Conf.constants.cheeringTweet [ class "link" ] [ text "come and say hi" ]
                    , text ". We are eager to learn how you use it and for what. We also love "
                    , extLink Conf.constants.azimuttFeatureRequests [ class "link" ] [ text "feedback and feature requests" ]
                    , text "."
                    ]
                ]
            ]
        ]
