module Flare
  ( Flare()
  , UI()
  , ElementId()
  , Label()
  , number
  , number_
  , numberRange
  , numberRange_
  , numberSlider
  , numberSlider_
  , int
  , int_
  , intRange
  , intRange_
  , intSlider
  , intSlider_
  , string
  , string_
  , boolean
  , boolean_
  , optional
  , optional_
  , button
  , buttons
  , select
  , select_
  , radioGroup
  , radioGroup_
  , fieldset
  , (<**>)
  , wrap
  , lift
  , liftSF
  , foldp
  , runFlareWith
  , runFlare
  , runFlareShow
  ) where

import Prelude

import Data.Array (head, catMaybes)
import Data.Maybe
import Data.Monoid
import Data.Foldable (traverse_)
import Data.Traversable (traverse)

import Control.Apply
import Control.Monad.Eff

import DOM
import DOM.Node.Types (Element())

import Signal as S
import Signal.Channel

type ElementId = String
type Label = String

-- | A `Flare` is a `Signal` with a corresponding list of HTML elements
-- | for the user interface components.
data Flare a = Flare (Array Element) (S.Signal a)

instance functorFlare :: Functor Flare where
  map f (Flare cs sig) = Flare cs (map f sig)

instance applyFlare :: Apply Flare where
  apply (Flare cs1 sig1) (Flare cs2 sig2) = Flare (cs1 <> cs2) (sig1 <*> sig2)

instance applicativeFlare :: Applicative Flare where
  pure x = Flare [] (pure x)

-- | The main data type for a Flare UI. It encapsulates the `Eff` action
-- | which is to be run when setting up the input elements and corresponding
-- | signals.
newtype UI e a = UI (Eff (dom :: DOM, chan :: Chan | e) (Flare a))

instance functorUI :: Functor (UI e) where
  map f (UI a) = UI $ map (map f) a

instance applyUI :: Apply (UI e) where
  apply (UI a1) (UI a2) = UI $ lift2 apply a1 a2

instance applicativeUI :: Applicative (UI e) where
  pure x = UI $ return (pure x)

instance semigroupUI :: (Semigroup a) => Semigroup (UI e a) where
  append = lift2 append

instance monoidUI :: (Monoid a) => Monoid (UI e a) where
  mempty = pure mempty

instance semiringUI :: (Semiring a) => Semiring (UI e a) where
  one = pure one
  mul = lift2 mul
  zero = pure zero
  add = lift2 add

instance ringUI :: (Ring a) => Ring (UI e a) where
  sub = lift2 sub

instance moduloSemiringUI :: (ModuloSemiring a) => ModuloSemiring (UI e a) where
  mod = lift2 mod
  div = lift2 div

instance divisionRingUI :: (DivisionRing a) => DivisionRing (UI e a)

instance numUI :: (Num a) => Num (UI e a)

instance boundedUI :: (Bounded a) => Bounded (UI e a) where
  top = pure top
  bottom = pure bottom

instance booleanAlgebraUI :: (BooleanAlgebra a) => BooleanAlgebra (UI e a) where
  conj = lift2 conj
  disj = lift2 disj
  not = map not

-- | Remove all children from a given parent element.
foreign import removeChildren :: forall e. ElementId
                              -> Eff (dom :: DOM | e) Unit

-- | Append a child element to the parent with the specified ID.
foreign import appendComponent :: forall e. ElementId
                               -> Element -> Eff (dom :: DOM | e) Unit

-- | Set the inner HTML of the specified element to the given value.
foreign import renderString :: forall e. ElementId
                            -> String
                            -> Eff (dom :: DOM | e) Unit

type CreateComponent a = forall e. Label
                         -> a
                         -> (a -> Eff (chan :: Chan) Unit)
                         -> Eff (dom :: DOM, chan :: Chan | e) Element

foreign import cNumber :: CreateComponent Number
foreign import cNumberRange :: String -> Number -> Number -> Number -> CreateComponent Number
foreign import cIntRange :: String -> Int -> Int -> CreateComponent Int
foreign import cString :: CreateComponent String
foreign import cBoolean :: CreateComponent Boolean
foreign import cButton :: forall a. a -> CreateComponent a
foreign import cSelect :: forall a. Array a -> (a -> String) -> CreateComponent a
foreign import cRadioGroup :: forall a. Array a -> (a -> String) -> CreateComponent a

-- | Set up the HTML element for a given component and create the corresponding
-- | signal channel.
createUI :: forall e a. (CreateComponent a) -> Label -> a -> UI e a
createUI createComp id default = UI $ do
  chan <- channel default
  comp <- createComp id default (send chan)
  let signal = subscribe chan
  return $ Flare [comp] signal

-- | Creates an input field for a `Number` from a given label and default
-- | value.
number :: forall e. Label -> Number -> UI e Number
number = createUI cNumber

-- | Like `number`, but without a label.
number_ :: forall e. Number -> UI e Number
number_ = number ""

-- | Creates an input field for a `Number` from a given label,
-- | minimum value, maximum value, step size as well as default value.
-- | The returned value is guaranteed to be within the given range.
numberRange :: forall e. Label -> Number -> Number -> Number -> Number -> UI e Number
numberRange id min max step default = createUI (cNumberRange "number" min max step) id default

-- | Like `numberRange`, but without a label.
numberRange_ :: forall e. Number -> Number -> Number -> Number -> UI e Number
numberRange_ = numberRange ""

-- | Creates a slider for a `Number` input from a given label,
-- | minimum value, maximum value, step size as well as default value.
numberSlider :: forall e. Label -> Number -> Number -> Number -> Number -> UI e Number
numberSlider id min max step default = createUI (cNumberRange "range" min max step) id default

-- | Like `numberSlider`, but without a label.
numberSlider_ :: forall e. Number -> Number -> Number -> Number -> UI e Number
numberSlider_ = numberSlider ""

-- | Creates an input field for an `Int` from a given label and default
-- | value. The returned value is guaranteed to be within the allowed integer
-- | range.
int :: forall e. Label -> Int -> UI e Int
int id = createUI (cIntRange "number" bottom top) id

-- | Like `int`, but without a label.
int_ :: forall e. Int -> UI e Int
int_ = int ""

-- | Creates an input field for an `Int` from a given label, minimum and
-- | maximum values as well as a default value. The returned value is
-- | guaranteed to be within the given range.
intRange :: forall e. Label -> Int -> Int -> Int -> UI e Int
intRange id min max default = createUI (cIntRange "number" min max) id default

-- | Like `intRange`, but without a label.
intRange_ :: forall e. Int -> Int -> Int -> UI e Int
intRange_ = intRange ""

-- | Creates a slider for an `Int` input from a given label, minimum and
-- | maximum values as well as a default value.
intSlider :: forall e. Label -> Int -> Int -> Int -> UI e Int
intSlider id min max default = createUI (cIntRange "range" min max) id default

-- | Like `intSlider`, but without a label.
intSlider_ :: forall e. Int -> Int -> Int -> UI e Int
intSlider_ = intSlider ""

-- | Creates a text field for a `String` input from a given label and default
-- | value.
string :: forall e. Label -> String -> UI e String
string = createUI cString

-- | Like `string`, but without a label.
string_ :: forall e. String -> UI e String
string_ = string ""

-- | Creates a checkbox for a `Boolean` input from a given label and default
-- | value.
boolean :: forall e. Label -> Boolean -> UI e Boolean
boolean = createUI cBoolean

-- | Like `boolean`, but without a label.
boolean_ :: forall e. Boolean -> UI e Boolean
boolean_ = boolean ""

-- | Creates a checkbox that returns `Just x` if enabled and `Nothing` if
-- | disabled. Takes a label, the initial state (enabled or disabled) and
-- | the default value `x`.
optional :: forall a e. Label -> Boolean -> a -> UI e (Maybe a)
optional id enabled x = ret <$> boolean id enabled
  where ret true = (Just x)
        ret false = Nothing

-- | Like `optional`, but without a label.
optional_ :: forall a e. Boolean -> a -> UI e (Maybe a)
optional_ = optional ""

-- | Creates a button which yields the first value in the default state and
-- | the second value when it is pressed.
button :: forall a e. Label -> a -> a -> UI e a
button id vDefault vPressed = createUI (cButton vPressed) id vDefault

-- | Create a button for each element of the array. The whole component
-- | returns `Nothing` if none of the buttons is pressed and `Just x` if
-- | the button corresponding to the element `x` is pressed.
buttons :: forall a e. Array a -> (a -> String) -> UI e (Maybe a)
buttons xs toString = (head <<< catMaybes) <$> traverse toButton xs
  where toButton x = button (toString x) Nothing (Just x)

-- | Creates a select box to choose from a list of options. The first option
-- | is selected by default. The rest of the options is given as an array.
select :: forall e a. Label -> a -> Array a -> (a -> String) -> UI e a
select id default xs toString = createUI (cSelect xs toString) id default

-- | Like `select`, but without a label.
select_ :: forall e a. a -> Array a -> (a -> String) -> UI e a
select_ = select ""

-- | Creates a group of radio buttons to choose from a list of options. The
-- | first option is selected by default. The rest of the options is given as
-- | an array.
radioGroup :: forall e a. Label -> a -> Array a -> (a -> String) -> UI e a
radioGroup id default xs toString = createUI (cRadioGroup xs toString) id default

-- | Like `radioGroup`, but without a label.
radioGroup_ :: forall e a. a -> Array a -> (a -> String) -> UI e a
radioGroup_ = radioGroup ""

foreign import toFieldset :: Label -> Array Element -> Element

-- | Group the components of a UI inside a fieldset element with a given title.
fieldset :: forall e a. Label -> UI e a -> UI e a
fieldset label (UI setup) = UI $ do
  (Flare cs sig) <- setup
  return $ Flare [toFieldset label cs] sig


infixl 4 <**>

-- | A flipped version of `<*>` for `UI` that arranges the components in the
-- | order of appearance.
(<**>) :: forall a b e. UI e a -> UI e (a -> b) -> UI e b
(<**>) (UI setup1) (UI setup2) = UI $ do
  (Flare cs1 sig1) <- setup1
  (Flare cs2 sig2) <- setup2
  return $ Flare (cs1 <> cs2) (sig2 <*> sig1)

-- | Encapsulate a `Signal` within a `UI` component.
wrap :: forall e a. (S.Signal a) -> UI e a
wrap sig = UI $ return $ Flare [] sig

-- | Lift a `Signal` inside the `Eff` monad to a `UI` component.
lift :: forall e a. Eff (chan :: Chan, dom :: DOM | e) (S.Signal a) -> UI e a
lift msig = UI $ do
  sig <- msig
  return $ Flare [] sig

-- | Lift a function from `Signal a` to `Signal b` to a function from
-- | `UI e a` to `UI e b` without affecting the components. For example:
-- |
-- | ``` purescript
-- | dropRepeats :: forall e a. (Eq a) => UI e a -> UI e a
-- | dropRepeats = liftSF S.dropRepeats
-- | ```
liftSF :: forall e a b. (S.Signal a -> S.Signal b)
       -> UI e a
       -> UI e b
liftSF f (UI setup) = UI do
  (Flare comp sig) <- setup
  return $ Flare comp (f sig)

-- | Create a past dependent component. The fold-function takes the current
-- | value of the component and the previous value of the output to produce
-- | the new value of the output.
foldp :: forall a b e. (a -> b -> b) -> b -> UI e a -> UI e b
foldp f x0 = liftSF (S.foldp f x0)

-- | Renders a Flare UI to the DOM and sets up all event handlers. The ID
-- | specifies the HTML element to which the controls are attached. The
-- | function argument will be mapped over the `Signal` inside the `Flare`.
runFlareWith :: forall e a. ElementId
             -> (a -> Eff (dom :: DOM, chan :: Chan | e) Unit)
             -> UI e a
             -> Eff (dom :: DOM, chan :: Chan | e) Unit
runFlareWith controls handler (UI setupUI) = do
  (Flare components signal) <- setupUI
  removeChildren controls
  traverse_ (appendComponent controls) components
  S.runSignal (map handler signal)

-- | Renders a Flare UI to the DOM and sets up all event handlers. The two IDs
-- | specify the DOM elements to which the controls and the output will be
-- | attached, respectively.
runFlare :: forall e.
            ElementId
         -> ElementId
         -> UI e String
         -> Eff (dom :: DOM, chan :: Chan | e) Unit
runFlare controls target = runFlareWith controls (renderString target)

-- | Like `runFlare` but uses `show` to convert the contained value to a
-- | `String` before rendering to the DOM.
runFlareShow :: forall e a. (Show a)
             => ElementId
             -> ElementId
             -> UI e a
             -> Eff (dom :: DOM, chan :: Chan | e) Unit
runFlareShow controls target ui = runFlare controls target (show <$> ui)
