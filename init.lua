-- um_smartshop_payment/init.lua
-- Handle smartshop payment digitally
-- Copyright (C) 2018  AiTechEye
-- Copyright (C) 2019-2024  flux
-- Copyright (C) 2024  1F616EMO
-- SPDX-License-Identifier: LGPL-3.0-or-later

local S = minetest.get_translator("um_smartshop_payment")
local api = smartshop.api

---@type { string: integer }
local reg_currencies = {}
local function add_currency(name, value)
    if minetest.registered_items[name] then
        reg_currencies[name] = value
    end
end

if minetest.get_modpath("currency") then
    add_currency("currency:minegeld", 1)
    add_currency("currency:minegeld_5", 5)
    add_currency("currency:minegeld_10", 10)
    add_currency("currency:minegeld_50", 50)
    add_currency("currency:minegeld_100", 100)
end

---@param stack ItemStack
---@return integer
local function get_value(stack)
    local name = stack:get_name()
    if not reg_currencies[name] then return nil end
    return reg_currencies[name] * stack:get_count()
end

local check_shop_add = smartshop.util.check_shop_add_remainder
local check_shop_removed = smartshop.util.check_shop_remove_remainder
local check_player_add = smartshop.util.check_player_add_remainder
local check_player_removed = smartshop.util.check_player_remove_remainder

api.register_purchase_mechanic({
    name = "um_smartshop_payment:um_smartshop_payment",
    description = "digital payment",
    allow_purchase = function(player, shop, i)
		local pay_stack = shop:get_pay_stack(i)
		local give_stack = shop:get_give_stack(i)
		local strict_meta = shop:is_strict_meta()

        local pay_value = get_value(pay_stack)
		if not pay_value then
			return
		end

		local player_inv = api.get_player_inv(player)
		local tmp_player_inv = player_inv:get_tmp_inv()
		local tmp_shop_inv = shop:get_tmp_inv()

		local count_to_remove = give_stack:get_count()
		local shop_removed = tmp_shop_inv:remove_item(give_stack, "give")
		local success = count_to_remove == shop_removed:get_count()

		local balance = unified_money.get_balance(player:get_player_name())
		if not balance then return false end
		success = success and (balance >= pay_value)

		local leftover = tmp_player_inv:add_item(shop_removed)
		success = success and (leftover:get_count() == 0)

		shop:destroy_tmp_inv(tmp_shop_inv)
		player_inv:destroy_tmp_inv(tmp_player_inv)

		return success
	end,
	do_purchase = function(player, shop, i)
		local player_inv = api.get_player_inv(player)
		local pay_stack = shop:get_pay_stack(i)
		local give_stack = shop:get_give_stack(i)
		local strict_meta = shop:is_strict_meta()

		unified_money.del_balance(player:get_player_name(), get_value(pay_stack))
		local shop_removed = shop:remove_item(give_stack, "give")

		local player_removed = pay_stack
		shop_removed, player_removed = api.do_transaction_transforms(player, shop, i, shop_removed, player_removed)

		local player_remaining = player_inv:add_item(shop_removed)
		local shop_remaining = shop:add_item(player_removed, "pay")

		check_shop_removed(shop, shop_removed, give_stack)
		check_player_removed(player_inv, shop, player_removed, pay_stack)
		check_player_add(player_inv, shop, player_remaining)
		check_shop_add(shop, shop_remaining)
	end,
})
