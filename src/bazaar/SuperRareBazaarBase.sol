// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IPayments} from "rareprotocol/aux/payments/IPayments.sol";
import {SuperRareBazaarStorage} from "./SuperRareBazaarStorage.sol";
import {IStakingSettings} from "rareprotocol/aux/marketplace/IStakingSettings.sol";
import {IRareStakingRegistry} from "../staking/registry/IRareStakingRegistry.sol";

/// @author koloz
/// @title SuperRareBazaarBase
/// @notice Base contract containing the internal functions for the SuperRareBazaar.
abstract contract SuperRareBazaarBase is SuperRareBazaarStorage {
  using SafeERC20 for IERC20;

  /////////////////////////////////////////////////////////////////////////
  // Internal Functions
  /////////////////////////////////////////////////////////////////////////

  /// @notice Checks to see if the currenccy address is eth or an approved erc20 token.
  /// @param _currencyAddress Address of currency (Zero address if eth).
  function _checkIfCurrencyIsApproved(address _currencyAddress) internal view {
    require(
      _currencyAddress == address(0) || approvedTokenRegistry.isApprovedToken(_currencyAddress),
      "Not approved currency"
    );
  }

  /// @notice Checks to see if the owner of the token has the marketplace approved.
  /// @param _originContract Contract address of the token being checked.
  /// @param _tokenId Token Id of the asset.
  function _ownerMustHaveMarketplaceApprovedForNFT(address _originContract, uint256 _tokenId) internal view {
    IERC721 erc721 = IERC721(_originContract);
    address owner = erc721.ownerOf(_tokenId);
    require(erc721.isApprovedForAll(owner, address(this)), "owner must have approved contract");
  }

  /// @notice Checks to see if the msg sender owns the token.
  /// @param _originContract Contract address of the token being checked.
  /// @param _tokenId Token Id of the asset.
  function _senderMustBeTokenOwner(address _originContract, uint256 _tokenId) internal view {
    IERC721 erc721 = IERC721(_originContract);
    require(erc721.ownerOf(_tokenId) == msg.sender, "sender must be the token owner");
  }

  /// @notice Verifies that the splits supplied are valid.
  /// @dev A valid split has the same number of splits and ratios.
  /// @dev There can only be a max of 5 parties split with.
  /// @dev Total of the ratios should be 100 which is relative.
  /// @param _splits The addresses the amount is being split with.
  /// @param _ratios The ratios each address in _splits is getting.
  function _checkSplits(address payable[] calldata _splits, uint8[] calldata _ratios) internal pure {
    require(_splits.length > 0, "checkSplits::Must have at least 1 split");
    require(_splits.length <= 5, "checkSplits::Split exceeded max size");
    require(_splits.length == _ratios.length, "checkSplits::Splits and ratios must be equal");
    uint256 totalRatio = 0;

    for (uint256 i = 0; i < _ratios.length; i++) {
      totalRatio += _ratios[i];
    }

    require(totalRatio == 100, "checkSplits::Total must be equal to 100");
  }

  /// @notice Checks to see if the sender has approved the marketplace to move tokens.
  /// @dev This is for offers/buys/bids and the allowance of erc20 tokens.
  /// @dev Returns on zero address because no allowance is needed for eth.
  /// @param _contract The address of the currency being checked.
  /// @param _amount The total amount being checked.
  function _senderMustHaveMarketplaceApproved(address _contract, uint256 _amount) internal view {
    if (_contract == address(0)) {
      return;
    }

    IERC20 erc20 = IERC20(_contract);

    require(erc20.allowance(msg.sender, address(this)) >= _amount, "sender needs to approve marketplace for currency");
  }

  /// @notice Checks the user has the correct amount and transfers to the marketplace.
  /// @dev If the currency used is eth (zero address) the msg value is checked.
  /// @dev If eth isnt used and eth is sent we revert the txn.
  /// @dev We need to check this contracts balance before and after the transfer to ensure no fee.
  /// @param _currencyAddress Currency address being checked and transfered.
  /// @param _amount Total amount of currency.
  function _checkAmountAndTransfer(address _currencyAddress, uint256 _amount) internal {
    if (_currencyAddress == address(0)) {
      require(msg.value == _amount, "not enough eth sent");
      return;
    }

    require(msg.value == 0, "msg.value should be 0 when not using eth");

    IERC20 erc20 = IERC20(_currencyAddress);
    uint256 balanceBefore = erc20.balanceOf(address(this));

    erc20.safeTransferFrom(msg.sender, address(this), _amount);

    uint256 balanceAfter = erc20.balanceOf(address(this));

    require(balanceAfter - balanceBefore == _amount, "not enough tokens transfered");
  }

  /// @notice Refunds an address the designated amount.
  /// @dev Return if amount being refunded is zero.
  /// @dev Forwards to payment contract if eth is being refunded.
  /// @param _currencyAddress Address of currency being refunded.
  /// @param _amount Amount being refunded.
  /// @param _marketplaceFee Marketplace Fee (percentage) paid by _recipient.
  /// @param _recipient Address amount is being refunded to.
  function _refund(
    address _currencyAddress,
    uint256 _amount,
    uint256 _marketplaceFee,
    address _recipient
  ) internal {
    if (_amount == 0) {
      return;
    }

    uint256 requiredAmount = _amount + ((_amount * _marketplaceFee) / 100);

    if (_currencyAddress == address(0)) {
      (bool success, bytes memory data) = address(payments).call{value: requiredAmount}(
        abi.encodeWithSignature("refund(address,uint256)", _recipient, requiredAmount)
      );

      require(success, string(data));
      return;
    }

    IERC20 erc20 = IERC20(_currencyAddress);
    erc20.safeTransfer(_recipient, requiredAmount);
  }

  /// @notice Sends a payout to all the necessary parties.
  /// @dev Note that _splitAddrs and _splitRatios are not checked for validity. Make sure supplied values are correct by using _checkSplits. 
  /// @dev Sends payments to the network, royalty if applicable, and splits for the rest.
  /// @dev Forwards payments to the payment contract if payout is happening in eth.
  /// @dev Total amount of ratios should be 100 and is relative to the total ratio left.
  /// @param _originContract Contract address of asset triggering a payout.
  /// @param _tokenId Token Id of the asset.
  /// @param _currencyAddress Address of currency being paid out.
  /// @param _amount Total amount to be paid out.
  /// @param _seller Address of the person selling the asset.
  /// @param _splitAddrs Addresses that funds need to be split against.
  /// @param _splitRatios Ratios for split pertaining to each address.
  function _payout(
    address _originContract,
    uint256 _tokenId,
    address _currencyAddress,
    uint256 _amount,
    address _seller,
    address payable[] memory _splitAddrs,
    uint8[] memory _splitRatios
  ) internal {
    require(_splitAddrs.length == _splitRatios.length, "Number of split addresses and ratios must be equal.");

    /*
        The overall flow for payouts is:
            1. Payout marketplace fee
            2. Primary/Secondary Payouts
                a. Primary -> If space sale, query space operator registry for platform comission and payout
                              Else query marketplace setting for primary sale comission and payout
                b. Secondary -> Query global royalty registry for recipients and amounts and payout
            3. Calculate the amount for each _splitAddr based on remaining amount and payout
         */

    // Recipients of marketplace fee
    uint256 remainingAmount = _amount;

    // Marketplace fee

    // Amounts for recipients of marketplace fee
    uint256 marketplaceFee = marketplaceSettings.calculateMarketplaceFee(_amount);

    address payable[] memory mktFeeRecip = new address payable[](2);
    mktFeeRecip[0] = payable(networkBeneficiary);
    mktFeeRecip[1] = payable(IRareStakingRegistry(stakingRegistry).getStakingInfoForUser(_seller).rewardAddress);
    uint256[] memory mktFee = new uint256[](2);
    mktFee[0] = IStakingSettings(address(marketplaceSettings)).calculateMarketplacePayoutFee(_amount);
    mktFee[1] = IStakingSettings(address(marketplaceSettings)).calculateStakingFee(_amount);

    _performPayouts(_currencyAddress, marketplaceFee, mktFeeRecip, mktFee);

    if (!marketplaceSettings.hasERC721TokenSold(_originContract, _tokenId)) {
      uint256[] memory platformFee = new uint256[](1);
      address payable[] memory platformRecip = new address payable[](1);
      platformRecip[0] = mktFeeRecip[0];

      if (spaceOperatorRegistry.isApprovedSpaceOperator(_seller)) {
        uint256 platformCommission = spaceOperatorRegistry.getPlatformCommission(_seller);

        remainingAmount = remainingAmount - ((_amount * platformCommission) / 100);

        platformFee[0] = (_amount * platformCommission) / 100;

        _performPayouts(_currencyAddress, platformFee[0], platformRecip, platformFee);
      } else {
        uint256 platformCommission = marketplaceSettings.getERC721ContractPrimarySaleFeePercentage(_originContract);

        remainingAmount = remainingAmount - ((_amount * platformCommission) / 100);

        platformFee[0] = (_amount * platformCommission) / 100;

        _performPayouts(_currencyAddress, platformFee[0], platformRecip, platformFee);
      }
    } else {
      (address payable[] memory receivers, uint256[] memory royalties) = royaltyEngine.getRoyalty(
        _originContract,
        _tokenId,
        _amount
      );

      uint256 totalRoyalties = 0;

      for (uint256 i = 0; i < royalties.length; i++) {
        totalRoyalties += royalties[i];
      }

      remainingAmount -= totalRoyalties;
      _performPayouts(_currencyAddress, totalRoyalties, receivers, royalties);
    }

    uint256[] memory remainingAmts = new uint256[](_splitAddrs.length);

    uint256 totalSplit = 0;

    for (uint256 i = 0; i < _splitAddrs.length; i++) {
      remainingAmts[i] = (remainingAmount * _splitRatios[i]) / 100;
      totalSplit += (remainingAmount * _splitRatios[i]) / 100;
    }
    _performPayouts(_currencyAddress, totalSplit, _splitAddrs, remainingAmts);
  }

  function _performPayouts(
    address _currencyAddress,
    uint256 _amount,
    address payable[] memory _recipients,
    uint256[] memory _amounts
  ) internal {
    if (_currencyAddress == address(0)) {
      (bool success, bytes memory data) = address(payments).call{value: _amount}(
        abi.encodeWithSelector(IPayments.payout.selector, _recipients, _amounts)
      );

      require(success, string(data));
    } else {
      IERC20 erc20 = IERC20(_currencyAddress);

      for (uint256 i = 0; i < _recipients.length; i++) {
        erc20.safeTransfer(_recipients[i], _amounts[i]);
      }
    }
  }
}
