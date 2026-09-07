import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Mints a primary key for any row in this database.
///
/// **Every** id in the app comes from here. Centralising it is what actually
/// holds the "ids are UUID v7" invariant of PRD §8 — a length or format
/// check on the column would only catch the crudest violations, and would
/// still let any other 36-character string through.
///
/// v7 rather than v4 because the first 48 bits are a millisecond timestamp,
/// so ids sort chronologically. That makes a raw table dump readable in
/// insertion order, and it keeps B-tree inserts local instead of scattering
/// them, which matters once a log table has a few years of sets in it.
String newId() => _uuid.v7();
