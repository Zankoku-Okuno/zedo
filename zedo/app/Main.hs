module Main where

import Data.Maybe
import System.Directory
import System.Environment
import System.Exit
import System.IO
import Control.Exception

import Zedo.Options
import Zedo.Find
import Zedo.Command
import Zedo.Db


envTarget = "ZEDO_TARGET"
envBaseDir = "ZEDO__BASEDIR"


main :: IO ()
main = lookupEnv envTarget >>= \case
        Nothing -> queen
        Just "" -> queen
        Just parent -> worker parent

queen :: IO ()
queen = do
    (opts, cmd) <- execParser options
    case cmd of
        Init -> do
            topDirs <- topDirsOrDie opts{ Zedo.Options.zedoDir = maybe (Just ".") Just (Zedo.Options.zedoDir opts) }
            withCurrentDirectory (Zedo.Find.zedoDir topDirs) $ do
                dispatch topDirs cmd
        _ -> do
            topDirs <- topDirsOrDie opts
            withCurrentDirectory (Zedo.Find.zedoDir topDirs) $ do
                withDb topDirs startRun
                dispatch topDirs cmd
    where
    options :: ParserInfo (TopOptions, Command)
    options = info (helper <*> parser)
        ( fullDesc
        <> progDesc "Rebuild target files when source files have changed."
        )
        where parser = (,) <$> topOptions <*> topCommands

worker :: FilePath -> IO ()
worker parent = do
    unsetEnv envTarget
    zedoDir <- lookupEnv envBaseDir
    let opts = TopOptions{ parent = Just parent, .. }
    topDirs <- topDirsOrDie opts
    cmd <- execParser options
    withCurrentDirectory (Zedo.Find.zedoDir topDirs) $
        dispatch topDirs cmd
    where
    options :: ParserInfo Command
    options = info (helper <*> subCommands)
        ( fullDesc
        <> progDesc "Rebuild target files when source files have changed."
        )


topDirsOrDie :: TopOptions -> IO TopDirs
topDirsOrDie opts@TopOptions{..} = do
    zedoDir <- case zedoDir of
        Just dir -> pure dir
        Nothing -> getCurrentDirectory
    topDirs <- findTopDirs opts >>= \case
        Just topDirs -> pure topDirs
        Nothing -> die "fatal: not a zedo project (or any parent directories)"
    pure topDirs
