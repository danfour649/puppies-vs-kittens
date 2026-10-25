class_name MasseyModule
extends Node3D
## THE MASSEY MODULE ROOT — 255 Massey Street as a drop-in module
## (docs/massey-zones.md §9). SCAFFOLD — implementation lands in
## this lane; see ~/pvk-module-PROGRESS.md.
##
## A host instantiates this node, hands it the §9.3 host surface
## via setup(host), and gets back the assembled house: interior
## zones at HouseSpec origins, the ZoneManager, the objectives
## registry, the occupants, the duo — and the CAT START
## (choose_cat: character select -> spawn in the ground floor).
## The PvK game (main.gd) is the first host; module/DROP-IN.md is
## the consumption contract for the GTA host.
