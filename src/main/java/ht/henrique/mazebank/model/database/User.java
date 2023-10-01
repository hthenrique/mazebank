package ht.henrique.mazebank.model.database;

import lombok.Data;
import lombok.ToString;
import org.bson.Document;
import org.bson.codecs.pojo.annotations.BsonDiscriminator;
import org.bson.types.Decimal128;
import org.bson.types.ObjectId;

@ToString
@Data
@BsonDiscriminator
public class User {
    private String _id;
    private String _userName;
    private String _userEmail;
    private String _userPass;
    private String _userCreatedAt;
    private Decimal128 _userBalance;

    public User(Document document){
        this._id = document.get("_id", ObjectId.class).toString();
        this._userName = document.getString("_userName");
        this._userEmail = document.getString("_userEmail");
        this._userPass = document.getString("_userPass");
        this._userCreatedAt = document.getString("_userCreatedAt");
        this._userBalance = document.get("_userBalance", Decimal128.class);
    }

}
