#include "ChessPiece.h"
#include <vector>
;

CREATE ELEMENT TABLE ChessPiece (
       name STRING FROM get_name(),
       color STRING FROM get_color());

CREATE TABLE ChessDB.ChessRow AS SELECT * FROM vector<ChessPiece>;

CREATE ELEMENT TABLE ChessBoard (
       row_id INT FROM TABLE ChessRow WITH BASE=self);

CREATE TABLE ChessDB.ChessBoard WITH BASE=board AS SELECT * FROM vector<vector<ChessPiece> >;
