package ht.henrique.mazebank.model.mapper;


import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.fetch.FetchUserResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Mappings;

@Mapper(componentModel = "spring")
public interface UserMapper {

    @Mappings({
            @Mapping(source = "create.username", target = "user_name"),
            @Mapping(source = "create.useremail", target = "user_email"),
            @Mapping(source = "create.userpass", target = "user_pass")
    })
    User createToUser(CreateRequest create);

    @Mappings({
            @Mapping(source = "user.uid", target = "uid"),
            @Mapping(source = "user.user_name", target = "userName"),
            @Mapping(source = "user.user_email", target = "userEmail"),
            @Mapping(source = "user.user_balance", target = "userBalance")
    })
    FetchUserResponse userToFetchUser(User user);
}
