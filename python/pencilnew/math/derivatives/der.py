# der.py
#
"""
This is a wrapper for the actual derivatives, currently 6th order with
ghost zones included (pencil-code style).
"""


from .der_6th_order_w_ghosts import \
    xder_6th, yder_6th, zder_6th, xder2_6th, yder2_6th, zder2_6th, \
    xder6_6th, yder6_6th, zder6_6th

xder = xder_6th
yder = yder_6th
zder = zder_6th

xder2 = xder2_6th
yder2 = yder2_6th
zder2 = zder2_6th

xder6 = xder6_6th
yder6 = yder6_6th
zder6 = zder6_6th

