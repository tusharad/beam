-- | This module implements an AST type for SQL92. It allows us to realize
--   the call structure of the builders defined in 'Database.Beam.Backend.SQL92'
module Database.Beam.Backend.SQL92.AST where

import Prelude hiding (Ordering)

import Database.Beam.Backend.SQL92

import Data.Text (Text)
import Data.Typeable

data Command
  = SelectCommand Select
  | InsertCommand Insert
  | UpdateCommand Update
  | DeleteCommand Delete
  deriving (Show, Eq)

instance IsSql92Syntax Command where
  type Sql92SelectSyntax Command = Select
  type Sql92UpdateSyntax Command = Update
  type Sql92InsertSyntax Command = Insert
  type Sql92DeleteSyntax Command = Delete

  selectCmd = SelectCommand
  insertCmd = InsertCommand
  updateCmd = UpdateCommand
  deleteCmd = DeleteCommand

data Select
  = Select
  { selectProjection :: Projection
  , selectFrom       :: Maybe From
  , selectWhere      :: Expression
  , selectGrouping   :: Maybe Grouping
  , selectOrdering   :: [ Ordering ]
  , selectLimit, selectOffset :: Maybe Integer }
  deriving (Show, Eq)

instance IsSql92SelectSyntax Select where
  type Sql92SelectExpressionSyntax Select = Expression
  type Sql92SelectProjectionSyntax Select = Projection
  type Sql92SelectFromSyntax Select = From
  type Sql92SelectGroupingSyntax Select = Grouping
  type Sql92SelectOrderingSyntax Select = Ordering

  selectStmt = Select

data Insert
  = Insert
  { insertTable :: Text
  , insertFields :: [ Text ]
  , insertValues :: InsertValues }
  deriving (Show, Eq)

instance IsSql92InsertSyntax Insert where
  type Sql92InsertValuesSyntax Insert = InsertValues

  insertStmt = Insert

data InsertValues
  = InsertValues
  { insertValuesExpressions :: [ [ Expression ] ] }
  | InsertSelect
  { insertSelectStmt :: Select }
  deriving (Show, Eq)

instance IsSql92InsertValuesSyntax InsertValues where
  type Sql92InsertValuesExpressionSyntax InsertValues = Expression
  type Sql92InsertValuesSelectSyntax InsertValues = Select

  insertSqlExpressions = InsertValues
  insertFromSql = InsertSelect

data Update
  = Update
  { updateTable :: Text
  , updateFields :: [ (FieldName, Expression) ]
  , updateWhere :: Expression }
  deriving (Show, Eq)

instance IsSql92UpdateSyntax Update where
  type Sql92UpdateFieldNameSyntax Update = FieldName
  type Sql92UpdateExpressionSyntax Update = Expression

  updateStmt = Update

data Delete
  = Delete
  { deleteTable :: Text
  , deleteWhere :: Expression }
  deriving (Show, Eq)

instance IsSql92DeleteSyntax Delete where
  type Sql92DeleteExpressionSyntax Delete = Expression

  deleteStmt = Delete

data FieldName
  = QualifiedField Text Text
  | UnqualifiedField Text
  deriving (Show, Eq)

instance IsSql92FieldNameSyntax FieldName where
  qualifiedField = QualifiedField
  unqualifiedField = UnqualifiedField

data Expression
  = ExpressionValue Value
  | ExpressionValues [ Expression ]

  | ExpressionIsJust Expression
  | ExpressionIsNothing Expression

  | ExpressionCase [(Expression, Expression)] Expression

  | ExpressionFieldName FieldName

  | ExpressionBinOp Text Expression Expression
  | ExpressionUnOp Text Expression

  | ExpressionFunction Text [Expression]

  | ExpressionExists Select
  deriving (Show, Eq)

instance IsSql92ExpressionSyntax Expression where
  type Sql92ExpressionValueSyntax Expression = Value
  type Sql92ExpressionSelectSyntax Expression = Select
  type Sql92ExpressionFieldNameSyntax Expression = FieldName

  valueE = ExpressionValue
  valuesE = ExpressionValues

  isJustE = ExpressionIsJust
  isNothingE = ExpressionIsNothing

  caseE = ExpressionCase

  fieldE = ExpressionFieldName

  andE = ExpressionBinOp "AND"
  orE = ExpressionBinOp "OR"

  eqE = ExpressionBinOp "=="
  neqE = ExpressionBinOp "<>"
  ltE = ExpressionBinOp "<"
  gtE = ExpressionBinOp ">"
  leE = ExpressionBinOp "<="
  geE = ExpressionBinOp ">="
  addE = ExpressionBinOp "+"
  subE = ExpressionBinOp "-"
  mulE = ExpressionBinOp "*"
  divE = ExpressionBinOp "/"
  modE = ExpressionBinOp "%"

  notE = ExpressionUnOp "NOT"
  negateE = ExpressionUnOp "-"

  absE x = ExpressionFunction "ABS" [x]

  existsE = ExpressionExists

data Projection
  = ProjExprs [ (Expression, Maybe Text ) ]
  deriving (Show, Eq)

instance IsSql92ProjectionSyntax Projection where
  type Sql92ProjectionExpressionSyntax Projection = Expression

  projExprs = ProjExprs

data Ordering
  = OrderingAsc Expression
  | OrderingDesc Expression
  deriving (Show, Eq)

instance IsSql92OrderingSyntax Ordering where
  type Sql92OrderingExpressionSyntax Ordering = Expression

  ascOrdering = OrderingAsc
  descOrdering = OrderingDesc

data Grouping = Grouping deriving (Show, Eq)

data TableSource
  = TableNamed Text
  deriving (Show, Eq)

instance IsSql92TableSourceSyntax TableSource where
  tableNamed = TableNamed

data From
  = FromTable TableSource (Maybe Text)
  | InnerJoin From From (Maybe Expression)
  | LeftJoin From From (Maybe Expression)
  | RightJoin From From (Maybe Expression)
  | OuterJoin From From (Maybe Expression)
  deriving (Show, Eq)

instance IsSql92FromSyntax From where
  type Sql92FromTableSourceSyntax From = TableSource
  type Sql92FromExpressionSyntax From = Expression

  fromTable = FromTable
  innerJoin = InnerJoin
  leftJoin = LeftJoin
  rightJoin = RightJoin

data Value where
  Value :: (Show a, Eq a, Typeable a) => a -> Value

instance (Show a, Eq a, Typeable a) => HasSqlValueSyntax Value a where
  sqlValueSyntax = Value

instance Eq Value where
  Value a == Value b =
    case cast a of
      Just a -> a == b
      Nothing -> False
instance Show Value where
  showsPrec prec (Value a) =
    showParen (prec > app_prec) $
    ("Value " ++ ).
    showsPrec (app_prec + 1) a
    where app_prec = 10