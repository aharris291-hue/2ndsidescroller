class_name PageView
extends RefCounted
## How a page is being viewed. Rule 2 of the book: page angle sets the view.

enum Mode {
	SIDE, ## The page stands up: pop-ups rise, gravity pulls, play is side-scrolling.
	TOP, ## The page lies flat (or Patch is in the Margin): eight-way top-down play.
}
