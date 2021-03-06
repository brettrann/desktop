import System.IO

import Control.Concurrent
import Control.Monad

import Data.List
import qualified Data.Map as M
import Data.Maybe
import Data.String.Utils

import Text.Blaze
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

import XMonad
import XMonad.Actions.Search
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.UrgencyHook
import XMonad.Layout.ComboP
import XMonad.Layout.MosaicAlt
import XMonad.Layout.Named
import XMonad.Layout.NoBorders
import XMonad.Layout.PerWorkspace
import XMonad.Layout.SimpleFloat
import XMonad.Layout.Tabbed
import XMonad.Layout.TwoPane
import qualified XMonad.StackSet as S
import XMonad.Util.EZConfig (additionalKeys, removeKeys)
import XMonad.Util.Run
import XMonad.Util.WorkspaceCompare

import Graphics.X11.ExtraTypes.XF86

import System.Environment

-- For default configuration, see
-- http://xmonad.org/xmonad-docs/xmonad/src/XMonad-Config.html

theme :: Theme
theme = defaultTheme { activeColor = "#FFE8C9"
                     , activeTextColor = "#000000"
                     , activeBorderColor = "#FFE8C9"
                     , urgentColor = "#FF0000"
                     , urgentTextColor = "#FFFFFF"
                     , urgentBorderColor = "#FFFFFF"
                     , fontName = "xft:ubuntu:size=9"
                     }

floatLayout = simpleFloat' shrinkText theme

tabbedLayout = tabbed shrinkText theme

gitWorkspace  = "4"
mailWorkspace = "6"
imWorkspace   = "7"

workspaceIcon :: String -> Maybe String
workspaceIcon s | s == gitWorkspace  = Just "code-fork"
                | s == mailWorkspace = Just "envelope-o"
                | s == imWorkspace   = Just "comment-o"
                | otherwise          = Nothing

imLayout = named "IM" $
    combineTwoP (TwoPane 0.03 0.2) rosterLayout mainLayout isRoster
    where rosterLayout    = smartBorders mosaicLayout
          mainLayout      = mosaicLayout
          isRoster        = pidginRoster `Or` skypeRoster
          pidginRoster    = And (ClassName "Pidgin") (Role "buddy_list")
          -- TODO: distinguish Skype's main window better
          skypeRoster     = Title $ skypeLogin ++ " - Skype™"
          skypeLogin      = "brettrann"

mosaicLayout = MosaicAlt M.empty

layout = onWorkspace imWorkspace imLayout $
        named "Mosaic" (smartBorders mosaicLayout)
    ||| named "Tabs" (smartBorders tabbedLayout)
    ||| named "Float" (smartBorders floatLayout)

myWorkspaces = map show [1..9] ++ ["0", "-", "="]

myManageHook = composeAll
    [ className =? "Gitg" --> doShift gitWorkspace
    , className =? "Nylas N1" --> doShift mailWorkspace
    , className =? "Pidgin" <||> className =? "Skype" --> doShift imWorkspace
    ]

modm = mod4Mask

maxVolume :: Double
maxVolume = 0x10000

pulseAudioDump :: MonadIO m => m [String]
pulseAudioDump = liftM lines $ runProcessWithInput "pacmd" ["dump"] ""

pulseAudioDumpLine :: MonadIO m => String -> m (Maybe String)
pulseAudioDumpLine prefix = do
    dump <- pulseAudioDump
    let filtered = filter (prefix `isPrefixOf`) dump
    return $ case filtered of
                 [line] -> Just line
                 _ -> Nothing

currentVolume :: MonadIO m => m Double
currentVolume = do
    volumeLine <- pulseAudioDumpLine "set-sink-volume"
    let volume = case volumeLine of
                     Just vline -> read $ last $ words vline
                     _ -> 0
    return $ volume / maxVolume

currentMute :: MonadIO m => m Bool
currentMute = do
    muteLine <- pulseAudioDumpLine "set-sink-mute"
    return $ case muteLine of
                 Just mline -> case last $ words mline of
                                   "no" -> False
                                   "yes" -> True
                                   x -> error x
                 _ -> True

currentSink :: MonadIO m => m String
currentSink = do
    sinkLine <- pulseAudioDumpLine "set-sink-volume"
    return $ case sinkLine of
                 Just line -> words line !! 1
                 Nothing -> "alsa_output.pci-0000_00_1b.0.analog-stereo"

setVolume :: MonadIO m => Double -> m ()
setVolume vol = do
    sink <- currentSink
    spawn $ "pacmd set-sink-volume " ++ sink ++ " " ++ show volVal
    where newVol = max 0 $ min 1 vol
          volVal = round $ newVol * maxVolume

setMute :: MonadIO m => Bool -> m ()
setMute mute = do
    sink <- currentSink
    spawn $ "pacmd set-sink-mute " ++ sink ++ " " ++ muteStr mute
    where muteStr True  = "yes"
          muteStr False = "no"

raiseVolume :: MonadIO m => Double -> m ()
raiseVolume percent = do
    vol <- currentVolume
    setVolume $ vol + (percent / 100)

lowerVolume :: MonadIO m => Double -> m ()
lowerVolume = raiseVolume . negate

toggleMute :: MonadIO m => m ()
toggleMute = do
    mute <- currentMute
    setMute $ not mute

screensaver :: MonadIO m => m ()
screensaver = spawn "gnome-screensaver-command -l"

suspend :: MonadIO m => m ()
suspend = spawn "systemctl suspend"

main = do
    -- GHC_PACKAGE_PATH and PATH are set by the wrapper script, unset it for
    -- programs started from under XMonad
    unsetEnv "GHC_PACKAGE_PATH"
    getEnv "PREVPATH" >>= setEnv "PATH"
    unsetEnv "PREVPATH"
    browser <- liftM (fromMaybe "chromium") $ lookupEnv "BROWSER"
    let keys = [ ((0                   , xF86XK_Messenger), spawn "pidgin")

               , ((0                   , xF86XK_Explorer), screensaver)
               , ((shiftMask           , xF86XK_Explorer), suspend)

               , ((0                   , xF86XK_ScreenSaver), screensaver)
               , ((0                   , xF86XK_HomePage), spawn browser)
               , ((0                   , xF86XK_Display), spawn "fix-env")
               -- Button with some windows on it on MacBook Pro
               , ((0                   , xF86XK_LaunchA), spawn "fix-env")

               , ((modm                , xK_F1), screensaver)
               , ((modm .|. shiftMask  , xK_F1), suspend)
               , ((modm                , xK_F2), spawn browser)

               , ((0                   , xF86XK_AudioRaiseVolume), raiseVolume 5)
               , ((0                   , xF86XK_AudioLowerVolume), lowerVolume 5)
               , ((0                   , xF86XK_AudioMute), toggleMute)

               , ((modm                , xK_b    ), sendMessage ToggleStruts)
               , ((modm                , xK_s    ), selectSearchBrowser browser google)

               , ((modm                , xK_o    ), spawn "synapse")

               , ((modm .|. controlMask, xK_space), sendMessage resetAlt)
               ]
               ++
               -- Switch/move windows to workspaces
               [((m .|. modm, k), windows $ f i)
                   | (i, k) <- zip myWorkspaces $ [xK_1 .. xK_9] ++ [xK_0, xK_minus, xK_equal]
                   , (f, m) <- [(S.greedyView, 0), (S.shift, shiftMask)]]
    xmproc <- spawnPipe "/usr/bin/xmobar /home/dev/.config/xmobar/xmobarrc"
    xmonad $ withUrgencyHook NoUrgencyHook $ defaultConfig
        { terminal = "terminator"
        , workspaces = myWorkspaces
        , handleEventHook = fullscreenEventHook
        , manageHook = manageDocks <+> myManageHook <+> manageHook defaultConfig
        , layoutHook = avoidStruts $ layoutHook defaultConfig
        , logHook = dynamicLogWithPP xmobarPP
                { ppOutput = hPutStrLn xmproc
                , ppTitle = xmobarColor "green" "" . shorten 50
                }
        , modMask = modm
        } `removeKeys`
        [ (modm                 , xK_p)
        , (modm                 , xK_Return)
        ] `additionalKeys` keys
