module Zedo.Command where

import Zedo.Options
import Zedo.Find
import Zedo.Build
import Zedo.Db

import System.FilePath
import System.Directory
import System.Environment hiding (setEnv)
import System.Process.Typed
import System.Exit
import Control.Monad


dispatch :: TopDirs -> Command -> IO ()
dispatch topDirs cmd = do
    case cmd of
        Init -> cmdInit topDirs
        Find target -> cmdFind topDirs target
        Always{..} -> buildMany find targets
        IfChange{..} -> buildMany find targets -- TODO
        Phony -> cmdPhony topDirs
    where
    buildMany find targets = do
        successes <- cmdAlways topDirs `mapM` targets
        if and successes
        then when find (cmdFind topDirs `mapM_` targets)
        else die "a dependency failed to build"

cmdInit :: TopDirs -> IO ()
cmdInit topDirs@TopDirs{..} = do -- FIXME move this elsewhere
    -- FIXME if it already exists, prompt to re-initialize it
    createDirectoryIfMissing True workDir -- FIXME could fail
    let versionFile = workDir </> ".version"
        dbFile = workDir </> "db.sqlite3"
    withNewDb topDirs $ \db -> do
        writeFile versionFile "zedo+sqlite v0.0.0"
        initDb db


-- FIXME should return success or failure instead of dieing
cmdFind :: TopDirs -> TargetOptions -> IO ()
cmdFind topDirs targetOpts = do
    findTargetFiles topDirs targetOpts >>= \case
        Nothing -> exitFailure
        Just TargetFiles{..} -> putStrLn targetFile


-- FIXME should return success or failure instead of dieing
cmdAlways :: TopDirs -> TargetOptions -> IO Bool
cmdAlways topDirs targetOpts = do
    targetFiles <- findTargetFiles topDirs targetOpts >>= \case
        Nothing -> exitFailure
        Just it -> pure it
    exitCode <- build topDirs targetFiles
    pure $ exitCode == ExitSuccess


cmdPhony :: TopDirs -> IO ()
cmdPhony topDirs@TopDirs{parent} =
    case parent of
        Nothing -> pure ()
        Just target -> withDb topDirs $ \db -> markPhony db target
