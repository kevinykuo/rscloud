#' Get list of members for space
#'
#' Returns the list of members for a given space. You must either be the admin
#' of the space or your role must have permissions to see the members list.
#'
#' @param space_id ID number of the space
#'
#' @export
space_member_get <- function(space_id) {

  check_auth()

  json_list <- rscloud_GET(path = c("spaces", space_id, "members"),
                           task = paste("Error retrieving members for space: ", space_id)
                           )

  if (length(json_list$users) == 0)
    stop(paste0("No users found for space: ", space_id),
         call. = FALSE)

  n_pages <- ceiling(json_list$total / json_list$count)

  batch_size <- json_list$count

  pages <- vector("list", n_pages)

  for (i in seq_along(pages)) {

    if (i == 1) {
      pages[[1]] <- json_list$users
    } else {
      offset <- (i - 1) * batch_size
      pages[[i]] <- rscloud_GET(path = c("spaces", space_id, "members"),
                                query = list(offset = offset),
                                task = paste("Error retrieving members for space: ", space_id)
                                )$users
    }
  }

  # Rectangling
  ff <- tibble::tibble(users = pages)
  df <- ff %>%
    tidyr::unnest_longer(users) %>%
    tidyr::unnest_wider(users)

  df %>%
    dplyr::select(user_id = id, email, display_name, updated_time,
           created_time, login_attempts, dplyr::everything()) %>%
    parse_times()
}


#' Invite a user to become a member of a space
#'
#' Invites a user to a space with their email address and with a given role,
#' and can also prompt an invitation email if `email_invite` is set to `TRUE`.
#'
#'
#' @param space_id ID number of the space
#' @param user_email Email address of the user to add
#' @param email_invite Indicates whether an email should be sent to the user with the invite, `TRUE` by default
#' @param email_message Message to be sent to the user should the `email_invite` flag be set to `TRUE`
#' @param space_role Desired role for the user in the space
#'
#' @export
space_member_add <- function( space_id, user_email,
                      email_invite = TRUE, email_message = "You are invited to this space",
                      space_role = "contributor") {

  check_auth()

  roles <- space_role(space_id)

  if (!space_role %in% roles$role)
    stop(paste0("Role: ", space_role, " isn't a valid role for space: ", space_id))

  user <- list(email = user_email, space_role = space_role)


  if (email_invite) {
    user <- c(user, invite_email = email_invite, invite_email_message = email_message)
  }

  req <- rscloud_POST(path = c("spaces", space_id, "members"),
                      body = user)
}


#' Remove member from space
#'
#' Removes a member with a given user ID from the space.
#'
#' @param space_id ID number of the space
#' @param user_id ID number of the user
#'
#' @export
space_member_remove <- function(space_id, user_id) {

  check_auth()

  req <- rscloud_DELETE(path = c("spaces", space_id, "members", user_id))

  if (succeeded(req)) {
    usethis::ui_done("Removed user {usethis::ui_value(user_id)} from space {usethis::ui_value(space_id)}.")
  }

  if (failed(req)) {
    usethis::ui_oops("Failed to remove user {usethis::ui_value(user_id)} from space {usethis::ui_value(space_id)}.")
  }

}
