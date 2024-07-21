package ht.henrique.mazebank.util;

import ht.henrique.mazebank.exception.UtilsException;
import ht.henrique.mazebank.model.type.ReturnCode;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public class HashString {
    public static String hash(String value) throws UtilsException {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(value.getBytes());
            byte[] digest = md.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return String.valueOf(sb);
        } catch (NoSuchAlgorithmException e) {
            throw new UtilsException(ReturnCode.INVALID_PARAMETERS, String.format("Algorithm not found: %s ", e.getLocalizedMessage()));
        }
    }
}
