import Data.Function
import Data.List

maybeLast [] = ""
maybeLast x = last x

pkg = maybeLast . groupBy (\x y -> (x == ':') == (y == ':'))

sortPkg = sortBy (compare `on` pkg)

main = getContents >>= return . unlines . sortPkg . lines >>= putStr
